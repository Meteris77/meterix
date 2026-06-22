Add-Type -AssemblyName PresentationFramework

# =========================
# LOAD APPS FROM GITHUB
# =========================
$appsUrl = "https://raw.githubusercontent.com/Meteris77/meterix/main/apps.json"

try {
    $apps = Invoke-RestMethod -Uri $appsUrl
}
catch {
    [System.Windows.MessageBox]::Show("Impossible de charger apps.json")
    exit
}

if (-not $apps) {
    [System.Windows.MessageBox]::Show("apps.json vide")
    exit
}

# =========================
# UI (WPF)
# =========================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Meterix Installer"
        Height="550"
        Width="520"
        WindowStartupLocation="CenterScreen">

    <Grid Margin="10">

        <StackPanel>

            <TextBlock Text="Meterix Installer"
                       FontSize="22"
                       FontWeight="Bold"
                       Margin="0,0,0,10"/>

            <ScrollViewer Height="400">
                <StackPanel Name="AppList"/>
            </ScrollViewer>

            <Button Name="InstallBtn"
                    Height="40"
                    Margin="0,10,0,0">
                Installer sélection
            </Button>

        </StackPanel>

    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$list = $window.FindName("AppList")
$btn  = $window.FindName("InstallBtn")

# =========================
# CREATE CHECKBOXES
# =========================
$items = @()

foreach ($app in $apps) {

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $app.name
    $cb.Margin = "5"

    $list.Children.Add($cb)

    $items += [PSCustomObject]@{
        cb  = $cb
        id  = $app.id
        url = $app.url
    }
}

# =========================
# INSTALL LOGIC
# =========================
$btn.Add_Click({

    foreach ($i in $items) {

        if ($i.cb.IsChecked -eq $true) {

            # -------------------------
            # WINGET APPS
            # -------------------------
            if ($i.id) {

                try {
                    Start-Process "winget" -ArgumentList "install --id $($i.id) -e --silent" -Wait
                }
                catch {
                    [System.Windows.MessageBox]::Show("Erreur winget: $($i.id)")
                }
            }

            # -------------------------
            # URL INSTALLERS (EXE/MSI)
            # -------------------------
            elseif ($i.url) {

                $url = $i.url
                $temp = "$env:TEMP\meterix_install"

                if ($url -match "\.msi") {
                    $file = "$temp.msi"
                }
                else {
                    $file = "$temp.exe"
                }

                try {
                    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
                }
                catch {
                    [System.Windows.MessageBox]::Show("Erreur téléchargement: $($i.name)")
                    continue
                }

                if (!(Test-Path $file) -or (Get-Item $file).Length -lt 100KB) {
                    [System.Windows.MessageBox]::Show("Fichier invalide: $($i.name)")
                    continue
                }

                try {
                    if ($file -like "*.msi") {
                        Start-Process "msiexec.exe" -ArgumentList "/i `"$file`" /quiet /norestart" -Wait
                    }
                    else {
                        Start-Process $file -Wait
                    }
                }
                catch {
                    [System.Windows.MessageBox]::Show("Erreur installation: $($i.name)")
                }
            }
        }
    }

})

# =========================
# SHOW WINDOW
# =========================
$window.ShowDialog() | Out-Null
