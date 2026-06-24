<#
    Météris Installer - Météris Informatique
    Lancement : irm https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1 | iex
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Contexte de sécurité requis pour les requêtes web GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# =========================
# CONFIGURATION
# =========================
$repoBase   = "https://raw.githubusercontent.com/Meteris77/meterix/main"
$appsUrl    = "$repoBase/apps.json"
$logoUrl    = "$repoBase/logo.png"
$selfUrl    = "https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1"

# =========================
# DROITS ADMINISTRATEUR
# =========================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $relaunch = [System.Windows.MessageBox]::Show(
        "Météris Installer fonctionne mieux avec des droits administrateur (certaines installations peuvent échouer sans cela).`n`nRelancer en tant qu'administrateur ?",
        "Météris Informatique",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($relaunch -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Start-Process powershell -Verb RunAs -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                "irm $selfUrl | iex"
            )
            exit
        } catch {
            [System.Windows.MessageBox]::Show("Impossible de relancer en administrateur. Le programme va continuer sans droits élevés.")
        }
    }
}

# =========================
# CHARGEMENT ET TRI DE LA LISTE D'APPLICATIONS
# =========================
try {
    $apps = Invoke-RestMethod -Uri $appsUrl
    if ($apps) {
        $apps = $apps | Sort-Object name
    }
}
catch {
    [System.Windows.MessageBox]::Show("Impossible de charger la liste des logiciels (apps.json).`n`n$($_.Exception.Message)", "Météris Informatique - Erreur")
    exit
}
if (-not $apps -or $apps.Count -eq 0) {
    [System.Windows.MessageBox]::Show("La liste des logiciels est vide.", "Météris Informatique - Erreur")
    exit
}

# =========================
# INTERFACE (WPF - Charte Météris)
# =========================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Météris Informatique - Météris Installer"
        Height="750" Width="580"
        MinHeight="650" MinWidth="500"
        WindowStartupLocation="CenterScreen"
        Background="#FFF4F7FA"
        FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="BrandBlue" Color="#0081B9"/>
        <SolidColorBrush x:Key="BrandBlueDark" Color="#00608A"/>
        <SolidColorBrush x:Key="BrandGray" Color="#556575"/>
        <SolidColorBrush x:Key="BorderGray" Color="#D1D9E0"/>
        <SolidColorBrush x:Key="BgLight" Color="#FFFFFF"/>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource BrandBlue}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource BrandBlueDark}"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#CBD5E1"/>
                    <Setter Property="Foreground" Value="#94A3B8"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="{StaticResource BrandGray}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="Medium"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderGray}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F1F5F9"/>
                    <Setter Property="BorderBrush" Value="{StaticResource BrandBlue}"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Foreground" Value="#CBD5E1"/>
                    <Setter Property="BorderBrush" Value="#E2E8F0"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="ProgressBar">
            <Setter Property="Foreground" Value="{StaticResource BrandBlue}"/>
            <Setter Property="Background" Value="#E2E8F0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid MinHeight="14">
                            <Border Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="4"/>
                            <Border Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="4" HorizontalAlignment="Left"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="16" Margin="0,0,0,16" BorderBrush="#E2E8F0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Image Name="LogoImage" Grid.Column="0" Width="64" Height="64" Margin="0,0,16,0" RenderOptions.BitmapScalingMode="HighQuality"/>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Météris Informatique" FontSize="24" FontWeight="Bold" Foreground="{StaticResource BrandBlue}"/>
                    <TextBlock Text="Météris Installer — Déploiement Automatisé" FontSize="13" Foreground="{StaticResource BrandGray}" Margin="0,2,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <TextBlock Grid.Row="1" Text="Cochez les applications nécessaires à la configuration de ce poste, puis lancez l'installation."
                   FontSize="13" Foreground="{StaticResource BrandGray}" TextWrapping="Wrap" Margin="4,0,4,14"/>

        <Grid Grid.Row="2" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" BorderBrush="{StaticResource BorderGray}" BorderThickness="1" CornerRadius="6" Background="White" Margin="0,0,8,0" Height="34">
                <TextBox Name="SearchBox" BorderThickness="0" Background="Transparent" Padding="8,0" VerticalContentAlignment="Center" FontSize="13"/>
            </Border>
            <Button Name="BtnSelectAll" Grid.Column="1" Content="Tout sélectionner" Style="{StaticResource SecondaryButton}" Margin="0,0,6,0" Height="34"/>
            <Button Name="BtnSelectNone" Grid.Column="2" Content="Tout désélectionner" Style="{StaticResource SecondaryButton}" Height="34"/>
        </Grid>

        <Border Grid.Row="3" BorderBrush="{StaticResource BorderGray}" BorderThickness="1" Background="White" CornerRadius="8">
            <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="8">
                <StackPanel Name="AppListPanel"/>
            </ScrollViewer>
        </Border>

        <Grid Grid.Row="4" Margin="4,16,4,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar Name="ProgressBarCtrl" Grid.Column="0" Height="14" Minimum="0"/>
            <TextBlock Name="ProgressText" Grid.Column="1" Text="" VerticalAlignment="Center" Foreground="{StaticResource BrandGray}" FontWeight="SemiBold" FontSize="13" MinWidth="75" Margin="12,0,0,0" HorizontalAlignment="Right"/>
        </Grid>

        <Button Name="BtnInstall" Grid.Row="5" Content="Lancer l'installation de la sélection" Style="{StaticResource PrimaryButton}" Height="46" Margin="0,14,0,0"/>

        <StackPanel Grid.Row="6" Margin="0,16,0,0">
            <Expander Header="Afficher le journal d'installation" Foreground="{StaticResource BrandGray}" FontSize="12" FontWeight="Medium">
                <Border BorderBrush="{StaticResource BorderGray}" BorderThickness="1" CornerRadius="6" Background="#FAFAFA" Margin="0,8,0,0">
                    <TextBox Name="LogBox" Height="130" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0" Background="Transparent"
                             VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" Padding="8"/>
                </Border>
            </Expander>
            <TextBlock Text="© Météris Informatique — support@meteris.fr" FontSize="11" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,16,0,0"/>
        </StackPanel>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$LogoImage       = $window.FindName("LogoImage")
$AppListPanel    = $window.FindName("AppListPanel")
$SearchBox       = $window.FindName("SearchBox")
$BtnSelectAll    = $window.FindName("BtnSelectAll")
$BtnSelectNone   = $window.FindName("BtnSelectNone")
$ProgressBarCtrl = $window.FindName("ProgressBarCtrl")
$ProgressText    = $window.FindName("ProgressText")
$BtnInstall      = $window.FindName("BtnInstall")
$LogBox          = $window.FindName("LogBox")

# =========================
# CHARGEMENT DU LOGO
# =========================
try {
    $wc = New-Object System.Net.WebClient
    $logoBytes = $wc.DownloadData($logoUrl)
    $ms = New-Object System.IO.MemoryStream(,$logoBytes)
    
    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit()
    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bmp.StreamSource = $ms
    $bmp.EndInit()
    $bmp.Freeze()
    
    $LogoImage.Source = $bmp
    $window.Icon = $bmp
}
catch {
    $LogoImage.Visibility = "Collapsed"
}

# =========================
# COULEURS DE STATUT (UI)
# =========================
$brushBlue  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0,129,185))
$brushGreen = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(34,197,94))
$brushRed   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(239,68,68))
$brushGray  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100,116,139))
$brushBorder= [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(241,245,249))

# =========================
# CONSTRUCTION DE LA LISTE
# =========================
$rows = @()
$idx = 0
foreach ($app in $apps) {

    $rowBorder = New-Object System.Windows.Controls.Border
    $rowBorder.BorderBrush = $brushBorder
    $rowBorder.BorderThickness = "0,0,0,1"
    $rowBorder.Padding = "6,8"

    $rowGrid = New-Object System.Windows.Controls.Grid
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colStatus = New-Object System.Windows.Controls.ColumnDefinition
    $colStatus.Width = [System.Windows.GridLength]::new(120)
    [void]$rowGrid.ColumnDefinitions.Add($colMain)
    [void]$rowGrid.ColumnDefinitions.Add($colStatus)

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $app.name
    $cb.FontSize = 14
    $cb.VerticalAlignment = "Center"
    $cb.Cursor = "Hand"
    [System.Windows.Controls.Grid]::SetColumn($cb, 0)
    [void]$rowGrid.Children.Add($cb)

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.Text = ""
    $statusText.FontSize = 12
    $statusText.FontWeight = "SemiBold"
    $statusText.HorizontalAlignment = "Right"
    $statusText.VerticalAlignment = "Center"
    $statusText.Foreground = $brushGray
    [System.Windows.Controls.Grid]::SetColumn($statusText, 1)
    [void]$rowGrid.Children.Add($statusText)

    $rowBorder.Child = $rowGrid
    [void]$AppListPanel.Children.Add($rowBorder)

    $rows += [PSCustomObject]@{
        Key        = "$idx"
        Name       = $app.name
        Id         = $app.id
        Url        = $app.url
        Args       = $app.args
        cb         = $cb
        StatusText = $statusText
        RowPanel   = $rowBorder
    }
    $idx++
}

# =========================
# RECHERCHE / FILTRE
# =========================
$SearchBox.Add_TextChanged({
    $term = $SearchBox.Text.Trim().ToLower()
    foreach ($row in $rows) {
        if ($term -eq "" -or $row.Name.ToLower().Contains($term)) {
            $row.RowPanel.Visibility = "Visible"
        } else {
            $row.RowPanel.Visibility = "Collapsed"
        }
    }
})

# =========================
# SELECTION AUTOMATIQUE
# =========================
$BtnSelectAll.Add_Click({
    foreach ($row in $rows) {
        if ($row.RowPanel.Visibility -eq "Visible") { $row.cb.IsChecked = $true }
    }
})
$BtnSelectNone.Add_Click({
    foreach ($row in $rows) {
        if ($row.RowPanel.Visibility -eq "Visible") { $row.cb.IsChecked = $false }
    }
})

# =========================
# LOGIQUE D'INSTALLATION SÉQUENTIELLE SANS ISOLATION
# =========================
function Write-GuiLog {
    param($message)
    $time = Get-Date -Format "HH:mm:ss"
    $LogBox.AppendText("[$time] $message`r`n")
    $LogBox.ScrollToEnd()
}

function Run-InstallationQueue {
    param($selectedItems)

    $total = $selectedItems.Count
    $index = 0

    $ProgressBarCtrl.Maximum = $total
    $ProgressBarCtrl.Value = 0

    foreach ($app in $selectedItems) {
        $index++
        $ProgressBarCtrl.Value = $index
        $ProgressText.Text = "$index / $total"

        $row = $rows | Where-Object { $_.Key -eq $app.Key }
        if ($row) {
            $row.StatusText.Text = "Installation..."
            $row.StatusText.Foreground = $brushBlue
        }

        Write-GuiLog "Installation de $($app.Name)..."
        $ok = $false

        if ($app.Id) {
            try {
                # Appel direct dans l'environnement de la session utilisateur
                $p = Start-Process "winget" -ArgumentList @(
                    "install", "--id", $app.Id, "-e", "--silent",
                    "--accept-source-agreements", "--accept-package-agreements",
                    "--force"
                ) -Wait -PassThru -WindowStyle Hidden

                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq -1978335189 -or $p.ExitCode -eq 3010) {
                    $ok = $true
                } else {
                    Write-GuiLog "Échec Winget (Code: $($p.ExitCode)). Tentative de réinitialisation TLS..."
                    # Correction dynamique si problème persistant de certificat
                    $null = Start-Process "winget" -ArgumentList @("source", "reset", "--force") -Wait -WindowStyle Hidden
                    $p = Start-Process "winget" -ArgumentList @(
                        "install", "--id", $app.Id, "-e", "--silent",
                        "--accept-source-agreements", "--accept-package-agreements"
                    ) -Wait -PassThru -WindowStyle Hidden
                    
                    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { $ok = $true }
                }
            }
            catch {
                Write-GuiLog "Erreur d'initialisation de l'outil Winget."
            }
        }

        # --- PROTOCOLE DE REPLI EN TÉLÉCHARGEMENT WEB DIRECT ---
        if (-not $ok -and $app.Url) {
            Write-GuiLog "Déclenchement du repli par téléchargement de l'exécutable..."
            $ext  = if ($app.Url -match "\.msi(\?.*)?$") { "msi" } else { "exe" }
            $file = Join-Path $env:TEMP ("meterix_{0}.{1}" -f $app.Key, $ext)
            try {
                Invoke-WebRequest -Uri $app.Url -OutFile $file -UseBasicParsing -TimeoutSec 180
                if ((Test-Path $file) -and (Get-Item $file).Length -gt 10KB) {
                    if ($ext -eq "msi") {
                        $p = Start-Process "msiexec.exe" -ArgumentList @("/i", "`"$file`"", "/quiet", "/norestart") -Wait -PassThru
                    } else {
                        $args = if ($app.Args) { $app.Args } else { "/S" }
                        $p = Start-Process $file -ArgumentList $args -Wait -PassThru
                    }
                    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { $ok = $true }
                }
            }
            catch {
                Write-GuiLog "Le serveur de téléchargement direct a renvoyé une erreur."
            }
            finally {
                if (Test-Path $file) { Remove-Item $file -ErrorAction SilentlyContinue }
            }
        }

        # --- MISE À JOUR DE L'INTERFACE GLOBALE ---
        if ($row) {
            if ($ok) {
                $row.StatusText.Text = "Installé"
                $row.StatusText.Foreground = $brushGreen
                Write-GuiLog "$($app.Name) : Terminé avec succès."
            } else {
                $row.StatusText.Text = "Erreur"
                $row.StatusText.Foreground = $brushRed
                Write-GuiLog "Échec critique permanent pour $($app.Name)."
            }
        }
        
        # Permet à la fenêtre WPF de rester fluide et de se redessiner
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{})
    }

    # Restauration des boutons
    $BtnInstall.IsEnabled    = $true
    $BtnSelectAll.IsEnabled  = $true
    $BtnSelectNone.IsEnabled = $true
    $SearchBox.IsEnabled     = $true

    $okCount  = @($rows | Where-Object { $_.StatusText.Text -eq "Installé" }).Count
    $errCount = @($rows | Where-Object { $_.StatusText.Text -eq "Erreur" }).Count

    [System.Windows.MessageBox]::Show(
        "Installation terminée.`n`nRéussies : $okCount`nÉchecs : $errCount`n`nConsultez le journal pour le détail.",
        "Météris Informatique",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
}

# =========================
# DECLENCHEMENT INSTALLATION
# =========================
$BtnInstall.Add_Click({
    $selected = $rows | Where-Object { $_.cb.IsChecked -eq $true }
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Sélectionnez au moins un logiciel à installer.", "Météris Informatique")
        return
    }

    foreach ($row in $rows) { $row.StatusText.Text = "" ; $row.StatusText.Foreground = $brushGray }
    foreach ($row in $selected) { $row.StatusText.Text = "En attente" }
    $LogBox.Text = ""

    $BtnInstall.IsEnabled    = $false
    $BtnSelectAll.IsEnabled  = $false
    $BtnSelectNone.IsEnabled = $false
    $SearchBox.IsEnabled     = $false

    $itemsData = $selected | ForEach-Object {
        [PSCustomObject]@{ Key = $_.Key; Name = $_.Name; Id = $_.Id; Url = $_.Url; Args = $_.Args }
    }

    # Exécution directe
    Run-InstallationQueue -selectedItems $itemsData
})

# =========================
# AFFICHAGE DE LA FENETRE
# =========================
$window.ShowDialog() | Out-Null
