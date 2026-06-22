<#
    Météris Installer - Météris Informatique
    Lancement : irm "https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1?v=$(Get-Random)" | iex
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# =========================
# CONFIGURATION
# =========================
$repoBase   = "https://raw.githubusercontent.com/Meteris77/meterix/main"
$appsUrl    = "$repoBase/apps.json?v=$(Get-Random)"
$logoUrl    = "https://raw.githubusercontent.com/Meteris77/meterix/main/Logo.png"
$selfUrl    = "$repoBase/install.ps1"

# Sécurité TLS pour le téléchargement
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# =========================
# DROITS ADMINISTRATEUR
# =========================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $relaunch = [System.Windows.MessageBox]::Show(
        "Météris Installer fonctionne mieux avec des droits administrateur.`n`nRelancer en tant qu'administrateur ?",
        "Météris Informatique",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($relaunch -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            Start-Process powershell -Verb RunAs -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                "irm ""$selfUrl`?v=$(Get-Random)"" | iex"
            )
            exit
        } catch {
            [System.Windows.MessageBox]::Show("Impossible de relancer en administrateur. Poursuite sans privilèges.")
        }
    }
}

# =========================
# CHARGEMENT ET TRI DES APPLICATIONS
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
# INTERFACE (WPF - Nettoyée et Robustifiée)
# =========================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Météris Informatique - Météris Installer"
        Height="800" Width="620"
        MinHeight="700" MinWidth="550"
        WindowStartupLocation="CenterScreen"
        Background="#FFF1F5F9"
        FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="BrandBlue" Color="#0081B9"/>
        <SolidColorBrush x:Key="BrandBlueDark" Color="#00608A"/>
        <SolidColorBrush x:Key="BrandGray" Color="#475569"/>
        <SolidColorBrush x:Key="TextDark" Color="#0F172A"/>
        <SolidColorBrush x:Key="BorderGray" Color="#E2E8F0"/>
        
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource BrandBlue}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" SnapsToDevicePixels="True">
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
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderGray}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F8FAFC"/>
                    <Setter Property="BorderBrush" Value="{StaticResource BrandBlue}"/>
                    <Setter Property="Foreground" Value="{StaticResource BrandBlue}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="White" CornerRadius="12" Padding="20,16" Margin="0,0,0,16" BorderBrush="{StaticResource BorderGray}" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Image Name="LogoImage" Grid.Column="0" Width="56" Height="56" Margin="0,0,16,0" RenderOptions.BitmapScalingMode="HighQuality"/>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Météris Informatique" FontSize="22" FontWeight="Bold" Foreground="{StaticResource BrandBlue}"/>
                    <TextBlock Text="Météris Installer — Déploiement Applicatif Automatisé" FontSize="13" Foreground="{StaticResource BrandGray}" Margin="0,2,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <Grid Grid.Row="1" Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" BorderBrush="{StaticResource BorderGray}" BorderThickness="1" CornerRadius="6" Background="White" Margin="0,0,8,0" Height="36">
                <TextBox Name="SearchBox" BorderThickness="0" Background="Transparent" Padding="10,0" VerticalContentAlignment="Center" FontSize="13" Foreground="{StaticResource TextDark}" Text="Rechercher un logiciel..."/>
            </Border>
            <Button Name="BtnSelectAll" Grid.Column="1" Content="Tout cocher" Style="{StaticResource SecondaryButton}" Width="110" Height="36" Margin="0,0,6,0"/>
            <Button Name="BtnSelectNone" Grid.Column="2" Content="Tout décocher" Style="{StaticResource SecondaryButton}" Width="110" Height="36"/>
        </Grid>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="0,0,4,0">
            <StackPanel Name="CategoriesContainer"/>
        </ScrollViewer>

        <Grid Grid.Row="3" Margin="4,20,4,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar Name="ProgressBarCtrl" Grid.Column="0" Height="10" Minimum="0" Background="#E2E8F0" Foreground="{StaticResource BrandBlue}">
                <ProgressBar.Template>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid MinHeight="10">
                            <Border Background="{TemplateBinding Background}" CornerRadius="5"/>
                            <Border Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="5" HorizontalAlignment="Left"/>
                        </Grid>
                    </ControlTemplate>
                </ProgressBar.Template>
            </ProgressBar>
            <TextBlock Name="ProgressText" Grid.Column="1" Text="" VerticalAlignment="Center" Foreground="{StaticResource BrandGray}" FontWeight="Bold" FontSize="13" MinWidth="65" Margin="16,0,0,0" HorizontalAlignment="Right"/>
        </Grid>

        <Button Name="BtnInstall" Grid.Row="4" Content="Lancer le déploiement des éléments sélectionnés" Style="{StaticResource PrimaryButton}" Height="48" Margin="0,16,0,0"/>

        <StackPanel Grid.Row="5" Margin="0,14,0,0">
            <Expander Header="Afficher la console technique" Foreground="{StaticResource BrandGray}" FontSize="12" FontWeight="SemiBold">
                <Border BorderBrush="{StaticResource BorderGray}" BorderThickness="1" CornerRadius="8" Background="#F8FAFC" Margin="0,6,0,0">
                    <TextBox Name="LogBox" Height="120" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0" Background="Transparent"
                             VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" Padding="10" Foreground="#334155"/>
                </Border>
            </Expander>
            <TextBlock Text="© Météris Informatique — support@meteris.fr" FontSize="11" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,14,0,0"/>
        </StackPanel>
    </Grid>
</Window>
'@

try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.MessageBox]::Show("Erreur critique lors de l'initialisation de l'interface graphique :`n`n$($_.Exception.Message)", "Météris Informatique - Erreur")
    exit
}

$LogoImage           = $window.FindName("LogoImage")
$CategoriesContainer = $window.FindName("CategoriesContainer")
$SearchBox           = $window.FindName("SearchBox")
$BtnSelectAll        = $window.FindName("BtnSelectAll")
$BtnSelectNone       = $window.FindName("BtnSelectNone")
$ProgressBarCtrl     = $window.FindName("ProgressBarCtrl")
$ProgressText        = $window.FindName("ProgressText")
$BtnInstall          = $window.FindName("BtnInstall")
$LogBox              = $window.FindName("LogBox")

# =========================
# CHARGEMENT SÉCURISÉ DU LOGO
# =========================
try {
    $httpClient = New-Object System.Net.Http.HttpClient
    $responseTask = $httpClient.GetByteArrayAsync($logoUrl)
    $logoBytes = $responseTask.GetAwaiter().GetResult()
    
    $ms = New-Object System.IO.MemoryStream(,$logoBytes)
    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit()
    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bmp.StreamSource = $ms
    $bmp.EndInit()
    $bmp.Freeze()
    
    $LogoImage.Source = $bmp
    $window.Icon = $bmp
    $httpClient.Dispose()
}
catch {
    $LogoImage.Visibility = "Collapsed"
}

$brushBlue  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0,129,185))
$brushGreen = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(34,197,94))
$brushRed   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(239,68,68))
$brushGray  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100,116,139))
$brushText  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(15,23,42))

# Placeholder Manuel
$placeholderText = "Rechercher un logiciel..."
$SearchBox.Foreground = [System.Windows.Media.Brushes]::Gray

$SearchBox.Add_GotFocus({
    if ($SearchBox.Text -eq $placeholderText) {
        $SearchBox.Text = ""
        $SearchBox.Foreground = $brushText
    }
})
$SearchBox.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($SearchBox.Text)) {
        $SearchBox.Text = $placeholderText
        $SearchBox.Foreground = [System.Windows.Media.Brushes]::Gray
    }
})

# =========================
# GÉNÉRATION DYNAMIQUE PAR CATÉGORIES & TRI ALPHA
# =========================
$rows = @()
$categoriesGrouped = $apps | Group-Object category | Sort-Object Name

foreach ($cat in $categoriesGrouped) {
    $catName = if ([string]::IsNullOrEmpty($cat.Name)) { "Divers" } else { $cat.Name }
    
    $catCard = New-Object System.Windows.Controls.Border
    $catCard.Background = [System.Windows.Media.Brushes]::White
    $catCard.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(226,232,240))
    $catCard.BorderThickness = "1"
    $catCard.CornerRadius = "8"
    $catCard.Margin = "0,0,0,14"
    $catCard.Padding = "14,12"

    $catStack = New-Object System.Windows.Controls.StackPanel

    $catHeader = New-Object System.Windows.Controls.TextBlock
    $catHeader.Text = $catName.ToUpper()
    $catHeader.FontSize = 12
    $catHeader.FontWeight = "Bold"
    $catHeader.Foreground = $brushBlue
    $catHeader.Margin = "2,0,0,8"
    [void]$catStack.Children.Add($catHeader)

    $appsStack = New-Object System.Windows.Controls.StackPanel

    $sortedApps = $cat.Group | Sort-Object name
    foreach ($app in $sortedApps) {
        
        $itemBorder = New-Object System.Windows.Controls.Border
        $itemBorder.Padding = "4,6"
        $itemBorder.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(248,250,252))
        $itemBorder.BorderThickness = "0,0,0,1"

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition ; $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition ; $c2.Width = [System.Windows.GridLength]::new(110)
        [void]$grid.ColumnDefinitions.Add($c1)
        [void]$grid.ColumnDefinitions.Add($c2)

        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $app.name
        $cb.FontSize = 13.5
        $cb.Foreground = $brushText
        $cb.VerticalAlignment = "Center"
        $cb.Cursor = "Hand"
        [System.Windows.Controls.Grid]::SetColumn($cb, 0)
        [void]$grid.Children.Add($cb)

        $st = New-Object System.Windows.Controls.TextBlock
        $st.Text = ""
        $st.FontSize = 11.5
        $st.FontWeight = "SemiBold"
        $st.HorizontalAlignment = "Right"
        $st.VerticalAlignment = "Center"
        $st.Foreground = $brushGray
        [System.Windows.Controls.Grid]::SetColumn($st, 1)
        [void]$grid.Children.Add($st)

        $itemBorder.Child = $grid
        [void]$appsStack.Children.Add($itemBorder)

        $rows += [PSCustomObject]@{
            Key        = "$($rows.Count)"
            Name       = $app.name
            Id         = $app.id
            Url        = $app.url
            Args       = $app.args
            cb         = $cb
            StatusText = $st
            ItemBorder = $itemBorder
            Card       = $catCard
        }
    }

    [void]$catStack.Children.Add($appsStack)
    $catCard.Child = $catStack
    [void]$CategoriesContainer.Children.Add($catCard)
}

# Recherche
$SearchBox.Add_TextChanged({
    $term = $SearchBox.Text.Trim().ToLower()
    if ($term -eq $placeholderText.ToLower()) { $term = "" }
    
    foreach ($row in $rows) {
        if ($term -eq "" -or $row.Name.ToLower().Contains($term)) {
            $row.ItemBorder.Visibility = "Visible"
        } else {
            $row.ItemBorder.Visibility = "Collapsed"
        }
    }
    foreach ($catCard in $CategoriesContainer.Children) {
        $stack = $catCard.Child
        $appsStack = $stack.Children[1]
        $hasVisible = $false
        foreach ($item in $appsStack.Children) {
            if ($item.Visibility -eq "Visible") { $hasVisible = $true; break }
        }
        $catCard.Visibility = if ($hasVisible) { "Visible" } else { "Collapsed" }
    }
})

$BtnSelectAll.Add_Click({
    foreach ($row in $rows) {
        if ($row.ItemBorder.Visibility -eq "Visible" -and $row.Card.Visibility -eq "Visible") { $row.cb.IsChecked = $true }
    }
})
$BtnSelectNone.Add_Click({
    foreach ($row in $rows) {
        if ($row.ItemBorder.Visibility -eq "Visible" -and $row.Card.Visibility -eq "Visible") { $row.cb.IsChecked = $false }
    }
})

# =========================
# PROCESSUS D'INSTALLATION
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
        Add-Log $sync "Déploiement de $($app.Name)..."
        $ok = $false

        if ($app.Id) {
            try {
                $p = Start-Process "winget" -ArgumentList @(
                    "install","--id",$app.Id,"-e","--silent",
                    "--accept-source-agreements","--accept-package-agreements","--force"
                ) -Wait -PassThru -WindowStyle Hidden
                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq -1978335189) { $ok = $true }
                else { Add-Log $sync "Échec winget (Code: $($p.ExitCode)) pour $($app.Name)." }
            }
            catch {
                Add-Log $sync "Erreur winget fatale pour $($app.Name) : $($_.Exception.Message)"
            }
        }
        elseif ($app.Url) {
            $ext  = if ($app.Url -match "\.msi(\?.*)?$") { "msi" } else { "exe" }
            $file = Join-Path $env:TEMP ("meterix_{0}.{1}" -f $app.Key, $ext)
            try {
                Invoke-WebRequest -Uri $app.Url -OutFile $file -UseBasicParsing
                if (!(Test-Path $file) -or (Get-Item $file).Length -lt 50KB) {
                    Add-Log $sync "Fichier téléchargé corrompu ou incomplet pour $($app.Name)"
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
                    else { Add-Log $sync "L'installeur de $($app.Name) a retourné le code d'erreur $($p.ExitCode)." }
                }
            }
            catch {
                Add-Log $sync "Erreur réseau/installation pour $($app.Name) : $($_.Exception.Message)"
            }
            finally {
                Remove-Item $file -ErrorAction SilentlyContinue
            }
        }

        if ($ok) {
            Add-Status $sync $app.Key "ok"
            Add-Log $sync "Succès : $($app.Name) configuré."
        } else {
            Add-Status $sync $app.Key "error"
        }
    }
    $sync.Running  = $false
    $sync.Finished = $true
}

$BtnInstall.Add_Click({
    $selected = $rows | Where-Object { $_.cb.IsChecked -eq $true }
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Sélectionnez au moins une application à déployer.", "Météris Informatique")
        return
    }

    foreach ($row in $rows) { $row.StatusText.Text = "" }
    foreach ($row in $selected) { $row.StatusText.Text = "En attente" ; $row.StatusText.Foreground = $brushGray }
    
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
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)

    $timer.Add_Tick({
        $ProgressBarCtrl.Maximum = [Math]::Max($sync.Total, 1)
        $ProgressBarCtrl.Value   = $sync.Index
        $ProgressText.Text       = "$($sync.Index) / $($sync.Total)"

        while ($sync.ConsumedStatus -lt $sync.StatusEvents.Count) {
            $evt = $sync.StatusEvents[$sync.ConsumedStatus]
            $row = $rows | Where-Object { $_.Key -eq $evt.Key }
            if ($row) {
                switch ($evt.Status) {
                    "installing" { $row.StatusText.Text = "En cours..." ; $row.StatusText.Foreground = $brushBlue }
                    "ok"         { $row.StatusText.Text = "Déployé"    ; $row.StatusText.Foreground = $brushGreen }
                    "error"      { $row.StatusText.Text = "Échec"      ; $row.StatusText.Foreground = $brushRed }
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

            $okCount  = @($rows | Where-Object { $_.StatusText.Text -eq "Déployé" }).Count
            $errCount = @($rows | Where-Object { $_.StatusText.Text -eq "Échec" }).Count

            try { [void]$ps.EndInvoke($asyncHandle) } catch {}
            $ps.Dispose()

            [System.Windows.MessageBox]::Show(
                "Déploiement terminé !`n`nLogiciels installés : $okCount`nÉchecs constatés : $errCount",
                "Météris Informatique",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    }.GetNewClosure())

    $timer.Start()
})

$window.ShowDialog() | Out-Null
