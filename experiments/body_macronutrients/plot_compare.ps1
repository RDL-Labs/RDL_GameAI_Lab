param([Parameter(Mandatory=$true)][string]$ResultDirectory)
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing
$diets=@('mixed','carbohydrate','fat','protein')
$labels=@('Mixed 50/25/25','Carb 70/15/15','Fat 15/15/70','Protein 15/70/15')
$colors=@('DimGray','RoyalBlue','DarkGoldenrod','MediumVioletRed')
$dayCount=[int](Import-Csv (Join-Path $ResultDirectory 'mixed/daily.csv') | Select-Object -Last 1).day
$chart=New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Width=1500; $chart.Height=1300; $chart.BackColor=[Drawing.Color]::White
$title=$chart.Titles.Add("Equal intake: 90 E/day, $dayCount days | shares = carbohydrate / protein / fat")
$title.Font=New-Object Drawing.Font('Segoe UI',17,[Drawing.FontStyle]::Bold)
$panels=@(
    @{Name='daily';Key='body_demand_mean';Title='Daily mean demand';Zoom=$false;Max=1;Min=0},
    @{Name='demand';Key='body_demand';Title='Body demand';Zoom=$true;Max=1;Min=0},
    @{Name='sugar';Key='sugar';Title='Sugar reserve (E)';Zoom=$true;Max=50;Min=0},
    @{Name='fat';Key='fat';Title='Fat at next wake (E)';Zoom=$false;Max=410;Min=190}
)
for($i=0;$i -lt $panels.Count;$i++) {
    $panel=$panels[$i]
    $area=New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea($panel.Name)
    $area.Position=New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition(2,(7+23*$i),96,23)
    $area.AxisX.Minimum=if($panel.Zoom){0}else{1}
    $area.AxisX.Maximum=if($panel.Zoom){24}else{$dayCount}
    $area.AxisX.Interval=if($panel.Zoom){2}else{[Math]::Max(1,[Math]::Ceiling($dayCount/10))}
    $area.AxisX.Title=if($panel.Zoom){"Day ${dayCount}: hours since 06:00 (meal=10; shaded=sleep)"}else{'Day'}
    $area.AxisY.Minimum=$panel.Min; $area.AxisY.Maximum=$panel.Max
    $area.AxisY.Title=$panel.Title
    $area.AxisY.LabelStyle.Format='0.##'
    $area.AxisX.MajorGrid.LineColor=[Drawing.Color]::Gainsboro
    $area.AxisY.MajorGrid.LineColor=[Drawing.Color]::Gainsboro
    $chart.ChartAreas.Add($area)
    $legend=New-Object System.Windows.Forms.DataVisualization.Charting.Legend($panel.Name)
    $legend.DockedToChartArea=$panel.Name; $legend.Docking='Top'; $legend.IsDockedInsideChartArea=$true
    $legend.Font=New-Object Drawing.Font('Segoe UI',10)
    $chart.Legends.Add($legend)
    if($panel.Zoom) {
        $shade=New-Object System.Windows.Forms.DataVisualization.Charting.StripLine
        $shade.IntervalOffset=16; $shade.StripWidth=8; $shade.BackColor=[Drawing.Color]::FromArgb(22,80,100,160)
        $area.AxisX.StripLines.Add($shade)
    }
    for($j=0;$j -lt $diets.Count;$j++) {
        $series=New-Object System.Windows.Forms.DataVisualization.Charting.Series("$i-$j")
        $series.ChartType='Line'; $series.BorderWidth=3
        $series.ChartArea=$panel.Name; $series.Legend=$panel.Name
        $series.LegendText=$labels[$j]; $series.Color=[Drawing.Color]::FromName($colors[$j])
        $file=if($panel.Zoom){'timeline.csv'}else{'daily.csv'}
        if($panel.Zoom -and (Test-Path (Join-Path $ResultDirectory ($diets[$j]+'/final_day_timeline.csv')))){$file='final_day_timeline.csv'}
        $rows=Import-Csv (Join-Path $ResultDirectory ($diets[$j]+'/'+$file))
        foreach($row in $rows) {
            if($panel.Zoom) {
                $hour=[double]::Parse($row.hour,[Globalization.CultureInfo]::InvariantCulture)
                $offset=($dayCount-1)*24
                if($hour -lt $offset){continue}; $x=$hour-$offset
            }else{$x=[double]$row.day}
            $y=[double]::Parse($row.($panel.Key),[Globalization.CultureInfo]::InvariantCulture)
            [void]$series.Points.AddXY([double]$x,[double]$y)
        }
        $chart.Series.Add($series)
    }
}
$chart.SaveImage((Join-Path $ResultDirectory 'comparison.png'),'Png')
$chart.Dispose()
