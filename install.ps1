Add-Type -AssemblyName PresentationFramework

$apps = Invoke-RestMethod "https://raw.githubusercontent.com/Meteris77/meterix/main/apps.json"

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Meterix Installer"
        Height="520"
        Width="550"
        WindowStartupLocation="CenterScreen">

    <Grid Margin="10">
        <StackPanel>

            <TextBlock Text="Meterix Installer"
                       FontSize="22"
                       FontWeight="Bold"
                       Margin="0,0,0,10"/>

            <ScrollViewer Height="380">
                <StackPanel Name="List"/>
            </ScrollViewer>

            <Button Name="Install"
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

$list = $window.FindName("List")
$btn = $window.FindName("Install")

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

$btn.Add_Click({

    foreach ($i in $items) {

        if ($i.cb.IsChecked) {

            # CAS 1 : winget
            if ($i.id) {
                Start-Process "winget" -ArgumentList "install --id $($i.id) -e --silent"
            }

            # CAS 2 : URL directe (exe/msi)
            if ($i.url) {
                $file = "$env:TEMP\installfile.exe"

                Invoke-WebRequest $i.url -OutFile $file

                Start-Process $file -Wait
            }
        }
    }
})

$window.ShowDialog() | Out-Null
