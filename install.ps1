Add-Type -AssemblyName PresentationFramework

$appsUrl = "https://raw.githubusercontent.com/Meteris77/meterix/main/apps.json"

try {
    $apps = Invoke-RestMethod -Uri $appsUrl
}
catch {
    [System.Windows.MessageBox]::Show("Erreur chargement apps.json")
    exit
}

if (-not $apps) {
    [System.Windows.MessageBox]::Show("apps.json vide ou introuvable")
    exit
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Meterix"
        Height="500"
        Width="500">

    <Grid Margin="10">
        <StackPanel>

            <TextBlock Text="Meterix Installer"
                       FontSize="20"
                       FontWeight="Bold"
                       Margin="0,0,0,10"/>

            <ScrollViewer Height="350">
                <StackPanel Name="List"/>
            </ScrollViewer>

            <Button Name="Install"
                    Height="40">
                Installer
            </Button>

        </StackPanel>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$list = $window.FindName("List")
$btn  = $window.FindName("Install")

$items = @()

foreach ($app in $apps) {

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $app.name
    $cb.Margin = "5"

    $list.Children.Add($cb)

    $items += [PSCustomObject]@{
        cb = $cb
        id = $app.id
    }
}

$btn.Add_Click({

    foreach ($i in $items) {

        if ($i.cb.IsChecked -eq $true) {

            if ($i.id) {
                Start-Process "winget" -ArgumentList "install --id $($i.id) -e --silent"
            }
        }
    }

})

$window.ShowDialog() | Out-Null
