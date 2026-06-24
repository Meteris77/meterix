<#
    Météris Installer - Nouvelle Version Ultra-Robuste
    Lancement : irm https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1 | iex
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# =========================
# CONFIGURATION
# =========================
$repoBase   = "https://raw.githubusercontent.com/Meteris77/meterix/main"
$appsUrl    = "$repoBase/apps.json"
$logoUrl    = "$repoBase/logo.png"
$selfUrl    = "$repoBase/install.ps1"

# =========================
# DROITS ADMINISTRATEUR
# =========================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $relaunch = [System.Windows.MessageBox]::Show(
        "Météris Installer requiert des droits administrateur pour installer les logiciels.`n`nRelancer en tant qu'administrateur ?",
        "Météris Informatique",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($relaunch -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Start-Process powershell -Verb RunAs -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm $selfUrl | iex")
            exit
        } catch {
            [System.Windows.MessageBox]::Show("Droits admin refusés. Fermeture.")
            exit
        }
    } else {
        exit
    }
}

# =========================
# CHARGEMENT DES DONNÉES
# =========================
try {
    $apps = Invoke-RestMethod -Uri $appsUrl -UseBasicParsing | Sort-Object name
} catch {
    [System.Windows.MessageBox]::Show("Impossible de récupérer apps.json :`n$($_.Exception.Message)", "Erreur Réseau")
    exit
}

# Téléchargement du logo en local pour WPF
$logoPath = Join-Path $env:TEMP "meteris_logo.png"
try { Invoke-WebRequest -Uri $logoUrl -OutFile $logoPath -UseBasicParsing -ErrorAction SilentlyContinue } catch {}

# =========================
# CODE INTERFACE XAML (WPF)
# =========================
$xamlCode = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Météris Informatique - Météris Installer"
        Height="720" Width="560" WindowStartupLocation="CenterScreen" Background="#FFF4F7FA" FontFamily="Segoe UI">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="15" Margin="0,0,0,15" BorderBrush="#E2E8F0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Image Name="LogoImage" Grid.Column="0" Width="50" Height="50" Margin="0,0,15,0"/>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Météris Informatique" FontSize="20" FontWeight="Bold" Foreground="#0081B9"/>
                    <TextBlock Text="Météris Installer — Déploiement Centralisé" FontSize="12" Foreground="#556575"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Recherche rapide -->
        <Grid Grid.Row="1" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox Name="SearchBox" Grid.Column="0" Height="32" Padding="5,0" VerticalContentAlignment="Center" Margin="0,0,5,0"/>
            <Button Name="BtnAll" Grid.Column="1" Content="Tout" Width="60" Margin="0,0,5,0"/>
            <Button Name="BtnNone" Grid.Column="2" Content="Rien" Width="60"/>
        </Grid>

        <!-- Liste des Apps -->
        <Border Grid.Row="2" BorderBrush="#D1D9E0" BorderThickness="1" Background="White" CornerRadius="6">
            <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="5">
                <StackPanel Name="AppContainer"/>
            </ScrollViewer>
        </Border>

        <!-- Barre de progression -->
        <Grid Grid.Row="3" Margin="0,15,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar Name="ProgBar" Height="14" Minimum="0" Maximum="100"/>
            <TextBlock Name="ProgText" Grid.Column="1" Text="0/0" Margin="10,0,0,0" FontWeight="Bold" Foreground="#556575"/>
        </Grid>

        <!-- Bouton Principal -->
        <Button Name="BtnGo" Grid.Row="4" Content="Lancer l'installation" Height="45" Margin="0,15,0,0" 
                Background="#0081B9" Foreground="White" FontWeight="Bold" FontSize="14">
            <Button.Resources>
                <Style TargetType="Border"><Setter Property="CornerRadius" Value="6"/></Style>
            </Button.Resources>
        </Button>

        <!-- Logs -->
        <Expander Grid.Row="5" Header="Voir le journal" Margin="0,10,0,0" Foreground="#556575">
            <TextBox Name="LogBox" Height="120" IsReadOnly="True" VerticalScrollBarVisibility="Auto" Background="#FAFAFA" FontFamily="Consolas" FontSize="11" Padding="5" TextWrapping="Wrap"/>
        </Expander>
    </Grid>
</Window>
"@

# =========================
# SYNCHRONISATION DES THREADS (Runspace Data)
# =========================
# On prépare un dictionnaire partagé pour piloter la fenêtre depuis l'arrière-plan sans saccade
$uiData = [hashtable]::Synchronized(@{
    Apps     = $apps
    Logo     = $logoPath
    Selected = [System.Collections.ArrayList]::new()
    Logs     = ""
    Status   = @{} # Stockage dynamique des statuts
    Progress = 0
    TotalStr = "0/0"
    Running  = $false
    SignalClose = $false
})

# =========================
# MOTEUR D'INSTALLATION (Arrière-plan)
# =========================
$installCode = {
    param($uiData)

    function Write-Log ($msg) {
        $time = Get-Date -Format "HH:mm:ss"
        $uiData.Logs += "[$time] $msg`r`n"
    }

    # FIX CRITIQUE WINGET : Recréation forcée des sources système manquantes en mode Administrateur
    function Fix-WingetSources {
        Write-Log "Vérification de la santé des sources Winget..."
        # On tente de réinitialiser complètement le gestionnaire de sources officiel
        $null = Start-Process winget -ArgumentList "source reset --force" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        $null = Start-Process winget -ArgumentList "source update" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }

    try {
        $list = $uiData.Selected.Clone()
        $total = $list.Count
        $current = 0
        
        if ($total -eq 0) { return }
        $uiData.Running = $true
        
        # On effectue le correctif de source avant de commencer au cas où un package utilise Winget
        Fix-WingetSources

        foreach ($app in $list) {
            $current++
            $uiData.TotalStr = "$current / $total"
            $uiData.Progress = ($current / $total) * 100
            $uiData.Status[$app.id] = "Installation..."
            
            Write-Log "Début du traitement pour : $($app.name)"
            $success = $false

            # --- STRATÉGIE 1 : TÉLÉCHARGEMENT DIRECT (Le plus robuste) ---
            if ($app.url) {
                Write-Log "-> Mode direct activé via URL."
                $ext = if ($app.url -match "\.msi(\?.*)?$") { "msi" } else { "exe" }
                $tmpFile = Join-Path $env:TEMP "install_$($app.id).$ext"
                
                try {
                    Invoke-WebRequest -Uri $app.Url -OutFile $tmpFile -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
                    if (Test-Path $tmpFile) {
                        Write-Log "Téléchargement terminé. Exécution de l'installeur..."
                        if ($ext -eq "msi") {
                            $proc = Start-Process "msiexec.exe" -ArgumentList @("/i", "`"$tmpFile`"", "/quiet", "/norestart") -Wait -PassThru -WindowStyle Hidden
                        } else {
                            $args = if ($app.args) { $app.args } else { "/S" }
                            $proc = Start-Process $tmpFile -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
                        }
                        
                        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                            $success = $true
                        } else {
                            Write-Log "L'installeur direct a retourné le code d'erreur : $($proc.ExitCode)"
                        }
                    }
                } catch {
                    Write-Log "Échec du téléchargement direct : $($_.Exception.Message)"
                } finally {
                    if (Test-Path $tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
                }
            }

            # --- STRATÉGIE 2 : REPLI PAR WINGET (Si pas d'URL ou si échec) ---
            if (-not $success -and $app.id) {
                Write-Log "-> Tentative via Microsoft Winget (ID: $($app.id))..."
                
                # Exécution sécurisée avec acceptation automatique des licences et isolation des erreurs de sources
                $wingetArgs = "install --id `"$($app.id)`" -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity --force"
                $proc = Start-Process winget -ArgumentList $wingetArgs -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq -1978335189)) {
                    $success = $true
                } else {
                    $code = if ($proc) { $proc.ExitCode } else { "Inconnu" }
                    Write-Log "Échec Winget. Code retour : $code"
                }
            }

            # Enregistrement du résultat final de l'application
            if ($success) {
                $uiData.Status[$app.id] = "Installé"
                Write-Log "Succès pour $($app.name)."
            } else {
                $uiData.Status[$app.id] = "Erreur"
                Write-Log "ÉCHEC permanent pour $($app.name)."
            }
        }
    } catch {
        Write-Log "Erreur générale critique de la file d'attente : $($_.Exception.Message)"
    } finally {
        $uiData.Running = $false
        $uiData.SignalClose = $true
    }
}

# =========================
# INITIALISATION DE L'INTERFACE (Thread UI principal)
# =========================
$xamlReader = New-Object System.Xml.XmlNodeReader ([xml]$xamlCode)
$window = [Windows.Markup.XamlReader]::Load($xamlReader)

# Récupération des contrôles
$LogoImage   = $window.FindName("LogoImage")
$SearchBox   = $window.FindName("SearchBox")
$BtnAll      = $window.FindName("BtnAll")
$BtnNone     = $window.FindName("BtnNone")
$AppContainer = $window.FindName("AppContainer")
$ProgBar     = $window.FindName("ProgBar")
$ProgText    = $window.FindName("ProgText")
$BtnGo       = $window.FindName("BtnGo")
$LogBox      = $window.FindName("LogBox")

# Application du logo
if (Test-Path $uiData.Logo) {
    try {
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource = [Uri]$uiData.Logo
        $bmp.EndInit()
        $LogoImage.Source = $bmp
        $window.Icon = $bmp
    } catch {}
}

# Génération dynamique des Checkbox d'applications dans l'UI
$uiRows = @()
foreach ($app in $uiData.Apps) {
    $grid = New-Object System.Windows.Controls.Grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::new(100)
    [void]$grid.ColumnDefinitions.Add($col1); [void]$grid.ColumnDefinitions.Add($col2)

    $cb = New-Object System.Windows.Controls.CheckBox -Property @{
        Content = $app.name
        FontSize = 13
        Margin = New-Object System.Windows.Thickness(5,4,5,4)
        VerticalAlignment = "Center"
    }
    [System.Windows.Controls.Grid]::SetColumn($cb, 0)
    [void]$grid.Children.Add($cb)

    $statusLabel = New-Object System.Windows.Controls.TextBlock -Property @{
        Text = ""
        FontSize = 12
        FontWeight = "Bold"
        HorizontalAlignment = "Right"
        VerticalAlignment = "Center"
        Foreground = [System.Windows.Media.Brushes]::Gray
    }
    [System.Windows.Controls.Grid]::SetColumn($statusLabel, 1)
    [void]$grid.Children.Add($statusLabel)

    [void]$AppContainer.Children.Add($grid)

    # Association de l'ID pour le suivi asynchrone
    $uiData.Status[$app.id] = ""

    $uiRows += [PSCustomObject]@{
        App         = $app
        CheckBox    = $cb
        StatusLabel = $statusLabel
        Wrapper     = $grid
    }
}

# =========================
# ACTIONS ET FILTRES DE L'INTERFACE
# =========================
$SearchBox.Add_TextChanged({
    $txt = $SearchBox.Text.Trim().ToLower()
    foreach ($row in $uiRows) {
        $row.Wrapper.Visibility = if ($txt -eq "" -or $row.App.name.ToLower().Contains($txt)) { "Visible" } else { "Collapsed" }
    }
})

$BtnAll.Add_Click({ foreach ($row in $uiRows) { if ($row.Wrapper.Visibility -eq "Visible") { $row.CheckBox.IsChecked = $true } } })
$BtnNone.Add_Click({ foreach ($row in $uiRows) { $row.CheckBox.IsChecked = $false } })

# Déclenchement de l'installation
$BtnGo.Add_Click({
    if ($uiData.Running) { return }

    $uiData.Selected.Clear()
    foreach ($row in $uiRows) {
        if ($row.CheckBox.IsChecked -eq $true) {
            [void]$uiData.Selected.Add($row.App)
            $row.StatusLabel.Text = "En attente"
            $row.StatusLabel.Foreground = [System.Windows.Media.Brushes]::Orange
        } else {
            $row.StatusLabel.Text = ""
        }
    }

    if ($uiData.Selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Veuillez cocher au moins un logiciel.", "Météris Informatique")
        return
    }

    # Désactivation globale des contrôles pendant le travail
    $BtnGo.IsEnabled = $false
    $BtnAll.IsEnabled = $false
    $BtnNone.IsEnabled = $false
    $SearchBox.IsEnabled = $false
    foreach ($row in $uiRows) { $row.CheckBox.IsEnabled = $false }

    $uiData.Logs = ""
    $uiData.SignalClose = $false

    # Lancement du Runspace en tâche de fond (True Multi-threading PowerShell)
    $iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
    $runspace = [runspacefactory]::CreateRunspace($iss)
    $runspace.Open()
    $powershell = [powershell]::Create().AddScript($installCode).AddArgument($uiData)
    $powershell.Runspace = $runspace
    [void]$powershell.BeginInvoke()
})

# =========================
# LE TIMER DE RAFRAÎCHISSEMENT DE L'UI (Évite les freezes)
# =========================
# Ce bloc tourne en boucle toutes les 200ms sur l'UI pour appliquer les changements faits en arrière-plan
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    # Mise à jour des textes de Logs
    if ($LogBox.Text -ne $uiData.Logs) {
        $LogBox.Text = $uiData.Logs
        $LogBox.ScrollToEnd()
    }

    # Mise à jour des barres et indicateurs de progression globale
    $ProgBar.Value = $uiData.Progress
    $ProgText.Text = $uiData.TotalStr

    # Mise à jour dynamique du statut individuel de chaque ligne d'application
    foreach ($row in $uiRows) {
        $currentStatus = $uiData.Status[$row.App.id]
        if ($row.StatusLabel.Text -ne $currentStatus) {
            $row.StatusLabel.Text = $currentStatus
            switch ($currentStatus) {
                "Installation..." { $row.StatusLabel.Foreground = [System.Windows.Media.Brushes]::DodgerBlue }
                "Installé"        { $row.StatusLabel.Foreground = [System.Windows.Media.Brushes]::Green }
                "Erreur"          { $row.StatusLabel.Foreground = [System.Windows.Media.Brushes]::Red }
                default           { $row.StatusLabel.Foreground = [System.Windows.Media.Brushes]::Gray }
            }
        }
    }

    # Fin des opérations détectée en tâche de fond
    if ($uiData.SignalClose) {
        $timer.Stop()
        $BtnGo.IsEnabled = $true
        $BtnAll.IsEnabled = $true
        $BtnNone.IsEnabled = $true
        $SearchBox.IsEnabled = $true
        foreach ($row in $uiRows) { $row.CheckBox.IsEnabled = $true }
        
        [System.Windows.MessageBox]::Show("Traitement de la file d'installation terminé !", "Météris Informatique", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        $uiData.SignalClose = $false
        $timer.Start() # Relance le récepteur au cas où l'utilisateur refait une sélection
    }
})

# Lancement du minuteur et ouverture définitive de l'application
$timer.Start()
[void]$window.ShowDialog()
$timer.Stop()
