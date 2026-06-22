<#
    Meterix Installer - Météris Informatique
    Lancement : irm https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1 | iex
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

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
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $relaunch = [System.Windows.MessageBox]::Show(
        "Meterix Installer fonctionne mieux avec des droits administrateur (certaines installations peuvent échouer sans cela).`n`nRelancer en tant qu'administrateur ?",
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
# CHARGEMENT DE LA LISTE D'APPLICATIONS
# =========================
try {
    $apps = Invoke-RestMethod -Uri $appsUrl
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
# INTERFACE (WPF)
# =========================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Météris Informatique - Meterix Installer"
        Height="720" Width="560"
        MinHeight="600" MinWidth="480"
        WindowStartupLocation="CenterScreen"
        Background="#FFF7F9FB"
        FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="BrandBlue" Color="#0081B9"/>
        <SolidColorBrush x:Key="BrandBlueDark" Color="#00608A"/>
        <SolidColorBrush x:Key="BrandGray" Color="#666666"/>
        <SolidColorBrush x:Key="BorderGray" Color="#E2E5E9"/>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource BrandBlue}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
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
                    <Setter Property="Background" Value="#C2C2C2"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="{StaticResource BrandGray}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderGray}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#EFF3F6"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Foreground" Value="#BBBBBB"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- En-tete -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,16">
            <Image Name="LogoImage" Width="58" Height="58" Margin="0,0,14,0"/>
            <StackPanel VerticalAlignment="Center">
                <TextBlock Text="Météris Informatique" FontSize="21" FontWeight="Bold" Foreground="{StaticResource BrandBlue}"/>
                <TextBlock Text="Meterix Installer" FontSize="13" Foreground="{StaticResource BrandGray}"/>
            </StackPanel>
        </StackPanel>

        <!-- Sous-titre -->
        <TextBlock Grid.Row="1" Text="Sélectionnez les logiciels à installer, puis cliquez sur Installer la sélection."
                   FontSize="12" Foreground="{StaticResource BrandGray}" TextWrapping="Wrap" Margin="0,0,0,12"/>

        <!-- Recherche + selection -->
        <Grid Grid.Row="2" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox Name="SearchBox" Grid.Column="0" Height="32" Padding="8,5"
                     VerticalContentAlignment="Center" BorderBrush="{StaticResource BorderGray}" Margin="0,0,8,0"/>
            <Button Name="BtnSelectAll" Grid.Column="1" Content="Tout sélectionner" Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
            <Button Name="BtnSelectNone" Grid.Column="2" Content="Tout désélectionner" Style="{StaticResource SecondaryButton}"/>
        </Grid>

        <!-- Liste des applications -->
        <Border Grid.Row="3" BorderBrush="{StaticResource BorderGray}" BorderThickness="1" Background="White" CornerRadius="5">
            <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="6">
                <StackPanel Name="AppListPanel"/>
            </ScrollViewer>
        </Border>

        <!-- Progression -->
        <Grid Grid.Row="4" Margin="0,14,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar Name="ProgressBarCtrl" Grid.Column="0" Height="16" Minimum="0" Margin="0,0,10,0"/>
            <TextBlock Name="ProgressText" Grid.Column="1" Text="" VerticalAlignment="Center" Foreground="{StaticResource BrandGray}" FontSize="12" MinWidth="70"/>
        </Grid>

        <!-- Bouton installer -->
        <Button Name="BtnInstall" Grid.Row="5" Content="Installer la sélection" Style="{StaticResource PrimaryButton}" Height="44" Margin="0,12,0,0"/>

        <!-- Journal + pied de page -->
        <StackPanel Grid.Row="6" Margin="0,14,0,0">
            <Expander Header="Journal d'installation" Foreground="{StaticResource BrandGray}" FontSize="12">
                <TextBox Name="LogBox" Height="120" IsReadOnly="True" TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11"
                         Background="#FAFAFA" BorderBrush="{StaticResource BorderGray}" Margin="0,8,0,0"/>
            </Expander>
            <TextBlock Text="© Météris Informatique" FontSize="10" Foreground="#AAAAAA" HorizontalAlignment="Center" Margin="0,12,0,0"/>
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
# LOGO
# =========================
try {
    $logoBytes = (New-Object System.Net.WebClient).DownloadData($logoUrl)
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
# COULEURS DE STATUT
# =========================
$brushBlue  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0,129,185))
$brushGreen = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(46,125,50))
$brushRed   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(198,40,40))
$brushGray  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(153,153,153))
$brushBorder= [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(226,229,233))

# =========================
# CONSTRUCTION DE LA LISTE
# =========================
$rows = @()
$idx = 0
foreach ($app in $apps) {

    $rowBorder = New-Object System.Windows.Controls.Border
    $rowBorder.BorderBrush = $brushBorder
    $rowBorder.BorderThickness = "0,0,0,1"
    $rowBorder.Padding = "4,6"

    $rowGrid = New-Object System.Windows.Controls.Grid
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $colStatus = New-Object System.Windows.Controls.ColumnDefinition
    $colStatus.Width = [System.Windows.GridLength]::new(110)
    [void]$rowGrid.ColumnDefinitions.Add($colMain)
    [void]$rowGrid.ColumnDefinitions.Add($colStatus)

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $app.name
    $cb.FontSize = 14
    $cb.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($cb, 0)
    [void]$rowGrid.Children.Add($cb)

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.Text = ""
    $statusText.FontSize = 12
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
# TOUT SELECTIONNER / DESELECTIONNER
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
# LOGIQUE D'INSTALLATION (execution en arriere-plan)
# =========================
$installWorker = {
    param($itemsData, $sync)

    function Add-Status { param($s,$k,$st) [void]$s.StatusEvents.Add(@{ Key = $k; Status = $st }) }
    function Add-Log    { param($s,$m) [void]$s.Log.Add("[" + (Get-Date -Format "HH:mm:ss") + "] " + $m) }

    $sync.Total   = $itemsData.Count
    $sync.Index   = 0
    $sync.Running = $true

    foreach ($app in $itemsData) {
        $sync.Index++
        Add-Status $sync $app.Key "installing"
        Add-Log $sync "Installation de $($app.Name)..."
        $ok = $false

        if ($app.Id) {
            try {
                $p = Start-Process "winget" -ArgumentList @(
                    "install","--id",$app.Id,"-e","--silent",
                    "--accept-source-agreements","--accept-package-agreements"
                ) -Wait -PassThru -WindowStyle Hidden
                if ($p.ExitCode -eq 0) { $ok = $true }
                else { Add-Log $sync "winget a retourné le code $($p.ExitCode) pour $($app.Name)." }
            }
            catch {
                Add-Log $sync "Erreur winget pour $($app.Name) : $($_.Exception.Message)"
            }
        }
        elseif ($app.Url) {
            $ext  = if ($app.Url -match "\.msi(\?.*)?$") { "msi" } else { "exe" }
            $file = Join-Path $env:TEMP ("meterix_{0}.{1}" -f $app.Key, $ext)
            try {
                Invoke-WebRequest -Uri $app.Url -OutFile $file -UseBasicParsing
                if (!(Test-Path $file) -or (Get-Item $file).Length -lt 100KB) {
                    Add-Log $sync "Fichier invalide ou trop petit : $($app.Name)"
                }
                else {
                    if ($ext -eq "msi") {
                        $p = Start-Process "msiexec.exe" -ArgumentList @("/i",$file,"/quiet","/norestart") -Wait -PassThru
                    }
                    elseif ($app.Args) {
                        $p = Start-Process $file -ArgumentList $app.Args -Wait -PassThru
                    }
                    else {
                        $p = Start-Process $file -Wait -PassThru
                    }
                    if ($p.ExitCode -eq 0) { $ok = $true }
                    else { Add-Log $sync "$($app.Name) a retourné le code $($p.ExitCode)." }
                }
            }
            catch {
                Add-Log $sync "Erreur téléchargement/installation de $($app.Name) : $($_.Exception.Message)"
            }
            finally {
                Remove-Item $file -ErrorAction SilentlyContinue
            }
        }
        else {
            Add-Log $sync "Aucune méthode d'installation définie pour $($app.Name)."
        }

        if ($ok) {
            Add-Status $sync $app.Key "ok"
            Add-Log $sync "$($app.Name) : installation réussie."
        }
        else {
            Add-Status $sync $app.Key "error"
        }
    }

    $sync.Running  = $false
    $sync.Finished = $true
}

# =========================
# CLIC SUR "INSTALLER LA SELECTION"
# =========================
$BtnInstall.Add_Click({

    $selected = $rows | Where-Object { $_.cb.IsChecked -eq $true }
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Sélectionnez au moins un logiciel à installer.", "Météris Informatique")
        return
    }

    # Reinitialisation visuelle
    foreach ($row in $rows) { $row.StatusText.Text = "" ; $row.StatusText.Foreground = $brushGray }
    foreach ($row in $selected) { $row.StatusText.Text = "En attente" }
    $LogBox.Text = ""
    $ProgressBarCtrl.Value = 0
    $ProgressText.Text = "0 / $($selected.Count)"

    $BtnInstall.IsEnabled    = $false
    $BtnSelectAll.IsEnabled  = $false
    $BtnSelectNone.IsEnabled = $false
    $SearchBox.IsEnabled     = $false

    $itemsData = $selected | ForEach-Object {
        [PSCustomObject]@{ Key = $_.Key; Name = $_.Name; Id = $_.Id; Url = $_.Url; Args = $_.Args }
    }

    $sync = [hashtable]::Synchronized(@{
        Total          = 0
        Index          = 0
        Running        = $false
        Finished       = $false
        ConsumedLog    = 0
        ConsumedStatus = 0
        Log            = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
        StatusEvents   = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    })

    $ps = [System.Management.Automation.PowerShell]::Create()
    [void]$ps.AddScript($installWorker).AddArgument($itemsData).AddArgument($sync)
    $asyncHandle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)

    $tickHandler = {
        $ProgressBarCtrl.Maximum = [Math]::Max($sync.Total, 1)
        $ProgressBarCtrl.Value   = $sync.Index
        $ProgressText.Text      = "$($sync.Index) / $($sync.Total)"

        while ($sync.ConsumedStatus -lt $sync.StatusEvents.Count) {
            $evt = $sync.StatusEvents[$sync.ConsumedStatus]
            $row = $rows | Where-Object { $_.Key -eq $evt.Key }
            if ($row) {
                switch ($evt.Status) {
                    "installing" { $row.StatusText.Text = "Installation..." ; $row.StatusText.Foreground = $brushBlue }
                    "ok"         { $row.StatusText.Text = "Installé"        ; $row.StatusText.Foreground = $brushGreen }
                    "error"      { $row.StatusText.Text = "Erreur"          ; $row.StatusText.Foreground = $brushRed }
                }
            }
            $sync.ConsumedStatus++
        }

        while ($sync.ConsumedLog -lt $sync.Log.Count) {
            $LogBox.AppendText($sync.Log[$sync.ConsumedLog] + "`r`n")
            $sync.ConsumedLog++
        }
        if ($sync.ConsumedLog -gt 0) { $LogBox.ScrollToEnd() }

        if ($sync.Finished) {
            $timer.Stop()
            $BtnInstall.IsEnabled    = $true
            $BtnSelectAll.IsEnabled  = $true
            $BtnSelectNone.IsEnabled = $true
            $SearchBox.IsEnabled     = $true

            $okCount  = ($rows | Where-Object { $_.StatusText.Text -eq "Installé" }).Count
            $errCount = ($rows | Where-Object { $_.StatusText.Text -eq "Erreur" }).Count

            try { [void]$ps.EndInvoke($asyncHandle) } catch {}
            $ps.Dispose()

            [System.Windows.MessageBox]::Show(
                "Installation terminée.`n`nRéussies : $okCount`nÉchecs : $errCount`n`nConsultez le journal pour le détail.",
                "Météris Informatique",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    }.GetNewClosure()

    $timer.Add_Tick($tickHandler)

    $timer.Start()
})

# =========================
# AFFICHAGE
# =========================
$window.ShowDialog() | Out-Null
