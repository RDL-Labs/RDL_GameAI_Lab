param([Parameter(Mandatory=$true)][string]$ResultDirectory)
# Standalone scientific time-series plots using the Windows .NET charting library.
# Run with Windows PowerShell 5.1; no UI, no new package dependencies.
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing
$rows=Import-Csv (Join-Path $ResultDirectory 'timeline.csv')
function Write-BodyChart([string]$FileName,[bool]$Zoom) {
    $chart=New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width=1500; $chart.Height=1250; $chart.BackColor=[Drawing.Color]::White
    $heading=if($Zoom){'Mixed diet: day 10 (hours since 06:00 wake)'}else{'Mixed diet: 10 days (day boundaries at 06:00)'}
    $title=$chart.Titles.Add($heading)
    $title.Font=New-Object Drawing.Font('Segoe UI',19,[Drawing.FontStyle]::Bold)
    $panels=@(
        @{Name='fuel';Title='Sugar / amino (E)';Keys=@('sugar','amino');Labels=@('Sugar reserve','Amino material');Colors=@('RoyalBlue','DarkOrange');Min=0;Max=50},
        @{Name='fat';Title='Fat reserve (E)';Keys=@('fat');Labels=@('Fat');Colors=@('DarkGoldenrod');Min=140;Max=280},
        @{Name='tissue';Title='Protein (E, zoomed)';Keys=@('tissue');Labels=@('Body protein');Colors=@('SeaGreen');Min=99.5;Max=100.1},
        @{Name='body_demand';Title='Body demand / fullness';Keys=@('body_demand','fullness');Labels=@('Body demand','Gut fullness');Colors=@('Crimson','SlateGray');Min=0;Max=1}
    )
    for($panelIndex=0;$panelIndex -lt $panels.Count;$panelIndex++) {
        $panel=$panels[$panelIndex]
        $area=New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea($panel.Name)
        $area.Position=New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition(2,(8+22*$panelIndex),96,22)
        $area.AxisX.Minimum=0; $area.AxisX.Maximum=if($Zoom){24}else{10}
        $area.AxisX.Interval=if($Zoom){2}else{1}
        $area.AxisX.Title=if($Zoom){'Hours since wake (meal=10, sleep=16..24)'}else{'Elapsed days'}
        $area.AxisY.Title=$panel.Title
        $area.AxisY.Minimum=$panel.Min; $area.AxisY.Maximum=$panel.Max
        $area.AxisY.LabelStyle.Format=if($panel.Name -eq 'tissue'){'0.0'}else{'0.##'}
        $area.AxisX.MajorGrid.LineColor=[Drawing.Color]::Gainsboro
        $area.AxisY.MajorGrid.LineColor=[Drawing.Color]::Gainsboro
        $area.AxisY.TitleFont=New-Object Drawing.Font('Segoe UI',11)
        $area.AxisX.TitleFont=New-Object Drawing.Font('Segoe UI',10)
        $chart.ChartAreas.Add($area)
        $legend=New-Object System.Windows.Forms.DataVisualization.Charting.Legend($panel.Name)
        $legend.DockedToChartArea=$panel.Name
        $legend.Docking='Top'; $legend.IsDockedInsideChartArea=$true
        $legend.Font=New-Object Drawing.Font('Segoe UI',10)
        $chart.Legends.Add($legend)
        if($Zoom) {
            $shade=New-Object System.Windows.Forms.DataVisualization.Charting.StripLine
            $shade.IntervalOffset=16; $shade.StripWidth=8
            $shade.BackColor=[Drawing.Color]::FromArgb(24,80,100,160)
            $area.AxisX.StripLines.Add($shade)
        }
        for($seriesIndex=0;$seriesIndex -lt $panel.Keys.Count;$seriesIndex++) {
            $key=$panel.Keys[$seriesIndex]
            $series=New-Object System.Windows.Forms.DataVisualization.Charting.Series($key)
            $series.ChartType='Line'; $series.BorderWidth=2
            $series.Color=[Drawing.Color]::FromName($panel.Colors[$seriesIndex])
            $series.ChartArea=$panel.Name; $series.Legend=$panel.Name
            $series.LegendText=$panel.Labels[$seriesIndex]
            foreach($row in $rows) {
                $hour=[double]::Parse($row.hour,[Globalization.CultureInfo]::InvariantCulture)
                if($Zoom -and $hour -lt 216){continue}
                $x=if($Zoom){$hour-216}else{$hour/24}
                $y=[double]::Parse($row.$key,[Globalization.CultureInfo]::InvariantCulture)
                [void]$series.Points.AddXY([double]$x,[double]$y)
            }
            $chart.Series.Add($series)
        }
    }
    $chart.SaveImage((Join-Path $ResultDirectory $FileName),'Png')
    $chart.Dispose()
}
Write-BodyChart 'mixed10.png' $false
Write-BodyChart 'day10.png' $true
