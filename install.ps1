<#
    Météris Installer - Version Initiale Stable
    Lancement : irm https://raw.githubusercontent.com/Meteris77/meterix/main/install.ps1 | iex
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# =========================
# CONFIGURATION & DONNÉES
# =========================
$appsUrl = "https://raw.githubusercontent.com/Meteris77/meterix/main/apps.json"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

try {
    $apps = Invoke-RestMethod -Uri $appsUrl
}
catch {
    [System.Windows.MessageBox]::Show("Impossible de charger la liste des applications : $($_.Exception.Message)")
    exit
}

# =========================
# INTERFACE GRAPHIQUE (XAML STABLE)
# =========================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Météris Installer" Height="650" Width="500" WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Sélectionnez les logiciels à installer" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="AppsContainer" Margin="5"/>
        </ScrollViewer>

        <ProgressBar Name="ProgressBarCtrl" Grid.Row="2" Height="20" Margin="0,10,0,10" Minimum="0" Maximum="100"/>
        <Button Name="BtnInstall" Grid.Row="3" Content="Installer la sélection" Height="35" FontWeight="Bold"/>
    </Grid>
</Window>
'@

# Chargement de la fenêtre
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$AppsContainer   = $window.FindName("AppsContainer")
$ProgressBarCtrl = $window.FindName("ProgressBarCtrl")
$BtnInstall      = $window.FindName("BtnInstall")

# =========================
# GÉNÉRATION DES LOGICIELS
# =========================
$checkboxes = @()

foreach ($app in $apps) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $app.name
    $cb.Margin = "0,4,0,4"
    $cb.FontSize = 13
    
    [void]$AppsContainer.Children.Add($cb)
    
    # On stocke la ligne avec ses infos de déploiement
    $checkboxes += [PSCustomObject]@{
        CheckBox = $cb
        Name     = $app.name
        Id       = $app.id
        Url      = $app.url
        Args     = $app.args
    }
}

# =========================
# LOGIQUE D'INSTALLATION
# =========================
$BtnInstall.Add_Click({
    $selectedApps = $checkboxes | Where-Object { $_.CheckBox.IsChecked -eq $true }
    
    if ($selectedApps.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Veuillez sélectionner au moins un logiciel.", "Météris Installer")
        return
    }

    $BtnInstall.IsEnabled = $false
    $ProgressBarCtrl.Maximum = $selectedApps.Count
    $ProgressBarCtrl.Value = 0

    foreach ($app in $selectedApps) {
        if ($app.Id) {
            # Installation via Winget
            Start-Process "winget" -ArgumentList "install --id $($app.Id) --silent --accept-source-agreements --accept-package-agreements" -Wait -WindowStyle Hidden
        }
        elseif ($app.Url) {
            # Installation via URL Directe
            $ext = if ($app.Url -match "\.msi") { "msi" } else { "exe" }
            $tempFile = Join-Path $env:TEMP "setup_$($app.Name.Replace(' ','_')).$ext"
            
            try {
                Invoke-WebRequest -Uri $app.Url -OutFile $tempFile -UseBasicParsing
                if ($ext -eq "msi") {
                    Start-Process "msiexec.exe" -ArgumentList "/i `"$tempFile`" /quiet /norestart" -Wait
                } else {
                    $args = if ($app.Args) { $app.Args } else { "/S" }
                    Start-Process $tempFile -ArgumentList $args -Wait
                }
            }
            catch {}
            finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
        $ProgressBarCtrl.Value++
    }

    [System.Windows.MessageBox]::Show("Installation terminée !", "Météris Installer")
    $ProgressBarCtrl.Value = 0
    $BtnInstall.IsEnabled = $true
})

# Affichage
$window.ShowDialog() | Out-Null
