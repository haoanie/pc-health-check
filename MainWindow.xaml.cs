using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace TiJianWinUI
{
    public sealed partial class MainWindow : Window
    {
        private static readonly Color OkC = Color.FromArgb(255, 22, 163, 74);
        private static readonly Color WarnC = Color.FromArgb(255, 217, 119, 6);
        private static readonly Color BadC = Color.FromArgb(255, 220, 38, 38);
        private static readonly Color PrimaryC = Color.FromArgb(255, 15, 118, 110);
        private static readonly Color AccentC = Color.FromArgb(255, 13, 148, 136);
        private static readonly Color GrayC = Color.FromArgb(255, 91, 107, 104);
        private static readonly Color SubC = Color.FromArgb(255, 130, 145, 142);
        private static readonly Color TextC = Color.FromArgb(255, 19, 78, 74);
        private static readonly Color CardC = Color.FromArgb(255, 252, 254, 253);
        private static readonly Color LineC = Color.FromArgb(255, 227, 236, 234);

        public MainWindow()
        {
            InitializeComponent();
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            var apw = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(
                Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwnd));
            apw.Resize(new Windows.Graphics.SizeInt32(1020, 840));
            string iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "app.ico");
            if (File.Exists(iconPath))
            {
                apw.SetIcon(iconPath);
            }
            _ = RunCheckAsync();
        }

        private async Task RunCheckAsync()
        {
            DeviceText.Text = "正在采集硬件与系统数据，请稍候…";
            ProgressBar.Value = 0;
            ProgressPct.Text = "0%";
            StatusText.Text = "正在初始化…";
            try
            {
                string json = await CollectJsonAsync();
                Render(json);
                ProgressBar.Value = 100;
                ProgressPct.Text = "100%";
                StatusText.Text = "体检完成";
            }
            catch (Exception ex)
            {
                DeviceText.Text = "体检失败";
                TimeText.Text = ex.Message;
            }
        }

        private async Task<string> CollectJsonAsync()
        {
            string script = Path.Combine(AppContext.BaseDirectory, "采集引擎JSON.ps1");
            if (!File.Exists(script))
                script = Path.Combine(Environment.CurrentDirectory, "采集引擎JSON.ps1");
            var psi = new ProcessStartInfo("powershell.exe")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = System.Text.Encoding.UTF8
            };
            psi.ArgumentList.Add("-NoProfile");
            psi.ArgumentList.Add("-ExecutionPolicy");
            psi.ArgumentList.Add("Bypass");
            psi.ArgumentList.Add("-File");
            psi.ArgumentList.Add(script);
            using var p = Process.Start(psi)!;
            string jsonPath = "";
            string? line;
            while ((line = await p.StandardOutput.ReadLineAsync()) != null)
            {
                if (line.StartsWith("PROGRESS|"))
                {
                    var seg = line.Substring("PROGRESS|".Length).Split('|');
                    if (seg.Length >= 1 && int.TryParse(seg[0], out int pct))
                    {
                        ProgressBar.Value = pct;
                        ProgressPct.Text = pct + "%";
                        StatusText.Text = seg.Length >= 2 ? seg[1] : "";
                    }
                }
                else if (line.Trim().Length > 0)
                {
                    jsonPath = line.Trim();
                }
            }
            await p.WaitForExitAsync();
            if (string.IsNullOrEmpty(jsonPath) || !File.Exists(jsonPath))
                throw new Exception("未获取到体检结果文件");
            return await File.ReadAllTextAsync(jsonPath, System.Text.Encoding.UTF8);
        }
        private void Render(string json)
        {
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            DeviceText.Text = r.GetProperty("Device").GetString() + "  |  " + r.GetProperty("Os").GetString();
            TimeText.Text = "体检时间：" + r.GetProperty("Time").GetString();

            BuildScore(r);
            BuildDisk(r);
            BuildJunk(r);
            BuildBig(r);
            BuildPerf(r);
            BuildBattery(r);
            BuildHabits(r);
            BuildSuggestions(r);
            DeviceText.Text = "体检完成  " + DeviceText.Text;
            string scls = r.GetProperty("ScoreCls").GetString() ?? "ok";
            string stxt = r.GetProperty("ScoreTxt").GetString() ?? "";
            Color sc2 = ColorFor(scls);
            BadgeText.Text = stxt;
            BadgeText.Foreground = new SolidColorBrush(sc2);
            BadgeDot.Fill = new SolidColorBrush(sc2);
            BadgeBorder.Visibility = Visibility.Visible;
        }

        private void BuildScore(JsonElement r)
        {
            int score = r.GetProperty("Score").GetInt32();
            string cls = r.GetProperty("ScoreCls").GetString() ?? "ok";
            string verdict = r.GetProperty("Verdict").GetString() ?? "";
            Color c = ColorFor(cls);

            var panel = new StackPanel { Spacing = 12 };
            var head = new StackPanel { Spacing = 10 };
            var starRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
            foreach (var s in BuildStars(score, c))
                starRow.Children.Add(s);
            starRow.Children.Add(new TextBlock
            {
                Text = score + "\u5206",
                FontSize = 22,
                FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                Foreground = new SolidColorBrush(c),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(6, 0, 0, 0)
            });
            head.Children.Add(starRow);
            head.Children.Add(new TextBlock { Text = verdict, FontSize = 13, Foreground = new SolidColorBrush(GrayC), TextWrapping = TextWrapping.Wrap });
            panel.Children.Add(head);
            var sc = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            sc.Children.Add(ScoreChip("磁盘", ScoreDim(r, "磁盘"), ColorFor(ScoreDimCls(r, "磁盘"))));
            sc.Children.Add(ScoreChip("性能", ScoreDim(r, "性能"), ColorFor(ScoreDimCls(r, "性能"))));
            sc.Children.Add(ScoreChip("电池", ScoreDim(r, "电池"), ColorFor(ScoreDimCls(r, "电池"))));
            sc.Children.Add(ScoreChip("清洁", ScoreDim(r, "清洁"), ColorFor(ScoreDimCls(r, "清洁"))));
            panel.Children.Add(sc);

            RootPanel.Children.Add(Card("综合评分", panel));
        }

        private void BuildDisk(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 10 };
            panel.Children.Add(Note(r.GetProperty("DiskNote").GetString()));
            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.7, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.4, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.0, GridUnitType.Star) });
            int row = 0;
            foreach (var d in r.GetProperty("Disks").EnumerateArray())
            {
                grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                string device = d.GetProperty("Device").GetString() ?? "";
                double total = d.GetProperty("TotalGB").GetDouble();
                double used = d.GetProperty("UsedGB").GetDouble();
                double pct = d.GetProperty("Pct").GetDouble();
                Color c = ColorFor(d.GetProperty("Cls").GetString());

                var t0 = new TextBlock { Text = device, FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
                Grid.SetRow(t0, row); Grid.SetColumn(t0, 0); grid.Children.Add(t0);

                var bar = Bar(pct, c);
                Grid.SetRow(bar, row); Grid.SetColumn(bar, 1); grid.Children.Add(bar);

                var t1 = new TextBlock
                {
                    Text = used.ToString("0.#") + " / " + total.ToString("0.#") + " GB（" + pct.ToString("0.#") + "%）",
                    FontSize = 12,
                    Foreground = new SolidColorBrush(c),
                    HorizontalAlignment = HorizontalAlignment.Right,
                    VerticalAlignment = VerticalAlignment.Center
                };
                Grid.SetRow(t1, row); Grid.SetColumn(t1, 2); grid.Children.Add(t1);
                row++;
            }
            panel.Children.Add(grid);
            RootPanel.Children.Add(Card("磁盘空间", panel));
        }

        private void BuildJunk(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 8 };
            panel.Children.Add(Note(r.GetProperty("JunkTip").GetString()));
            foreach (var j in r.GetProperty("JunkRows").EnumerateArray())
            {
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.2, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.6, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.2, GridUnitType.Star) });
                var name = new TextBlock { Text = j.GetProperty("Name").GetString(), FontSize = 12, VerticalAlignment = VerticalAlignment.Center };
                var size = new TextBlock { Text = j.GetProperty("Size").GetString(), FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(ColorFor(j.GetProperty("Cls").GetString())), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                var tip = new TextBlock { Text = j.GetProperty("Tip").GetString(), FontSize = 12, Foreground = new SolidColorBrush(GrayC), TextAlignment = TextAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                Grid.SetColumn(name, 0); g.Children.Add(name);
                Grid.SetColumn(size, 1); g.Children.Add(size);
                Grid.SetColumn(tip, 2); g.Children.Add(tip);
                panel.Children.Add(g);
            }
            RootPanel.Children.Add(Card("垃圾与缓存", panel));
        }

        private void BuildBig(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 8 };
            panel.Children.Add(Note(r.GetProperty("BigWarn").GetString()));
            foreach (var f in r.GetProperty("BigFiles").EnumerateArray())
            {
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.35, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.9, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.75, GridUnitType.Star) });
                var idx = new TextBlock { Text = "#" + f.GetProperty("Idx").GetInt32().ToString(), FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
                var path = new TextBlock { Text = f.GetProperty("Path").GetString(), FontSize = 12, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis };
                var size = new TextBlock { Text = f.GetProperty("Size").GetString(), FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(ColorFor(f.GetProperty("Cls").GetString())), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                Grid.SetColumn(idx, 0); g.Children.Add(idx);
                Grid.SetColumn(path, 1); g.Children.Add(path);
                Grid.SetColumn(size, 2); g.Children.Add(size);
                panel.Children.Add(g);
            }
            RootPanel.Children.Add(Card("大文件", panel));
        }

        private void BuildPerf(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 10 };
            var cpu = new TextBlock
            {
                Text = r.GetProperty("CpuName").GetString() + " ｜ " + r.GetProperty("CpuCores").GetInt32().ToString() + " 逻辑核心",
                FontSize = 13,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                TextWrapping = TextWrapping.Wrap
            };
            panel.Children.Add(cpu);

            double memUsed = r.GetProperty("MemUsed").GetDouble();
            double memTotal = r.GetProperty("MemTotal").GetDouble();
            double memPct = r.GetProperty("MemPct").GetDouble();
            Color memC = ColorFor(memPct >= 85 ? "bad" : memPct >= 70 ? "warn" : "ok");
            var g = new Grid();
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.2, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.4, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.2, GridUnitType.Star) });
            var l1 = new TextBlock { Text = "内存占用", FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
            var v1 = new TextBlock { Text = memUsed.ToString("0.#") + " / " + memTotal.ToString("0.#") + " GB", FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(memC), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            var b1 = Bar(memPct, memC);
            Grid.SetRow(l1, 0); Grid.SetColumn(l1, 0); g.Children.Add(l1);
            Grid.SetRow(b1, 0); Grid.SetColumn(b1, 1); g.Children.Add(b1);
            Grid.SetRow(v1, 0); Grid.SetColumn(v1, 2); g.Children.Add(v1);
            var l2 = new TextBlock { Text = "CPU 占用", FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
            var v2 = new TextBlock { Text = r.GetProperty("CpuTxt").GetString(), FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(PrimaryC), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            var l3 = new TextBlock { Text = "运行进程", FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
            var v3 = new TextBlock { Text = r.GetProperty("ProcCount").GetInt32().ToString() + " 个", FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(PrimaryC), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetRow(l2, 1); Grid.SetColumn(l2, 0); g.Children.Add(l2);
            Grid.SetRow(v2, 1); Grid.SetColumn(v2, 2); g.Children.Add(v2);
            Grid.SetRow(l3, 2); Grid.SetColumn(l3, 0); g.Children.Add(l3);
            Grid.SetRow(v3, 2); Grid.SetColumn(v3, 2); g.Children.Add(v3);
            g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            panel.Children.Add(g);

            panel.Children.Add(Note(r.GetProperty("StartupNote").GetString()));
            foreach (var s in r.GetProperty("StartupRows").EnumerateArray())
            {
                var sg = new Grid();
                sg.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.4, GridUnitType.Star) });
                sg.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.6, GridUnitType.Star) });
                sg.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.2, GridUnitType.Star) });
                var n = new TextBlock { Text = s.GetProperty("Name").GetString(), FontSize = 12, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis };
                var st = new TextBlock { Text = s.GetProperty("State").GetString(), FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
                var rt = new TextBlock { Text = s.GetProperty("RecTxt").GetString(), FontSize = 12, Foreground = new SolidColorBrush(ColorFor(s.GetProperty("Rec").GetString())), TextAlignment = TextAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                Grid.SetColumn(n, 0); sg.Children.Add(n);
                Grid.SetColumn(st, 1); sg.Children.Add(st);
                Grid.SetColumn(rt, 2); sg.Children.Add(rt);
                panel.Children.Add(sg);
            }
            RootPanel.Children.Add(Card("性能与自启动", panel));
        }

        private void BuildBattery(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 10 };
            bool has = r.GetProperty("HasBattery").GetBoolean();
            if (!has)
            {
                panel.Children.Add(Note("未检测到电池（台式机或电池被移除），电池维度不参与评分。"));
            }
            else
            {
                string health = r.GetProperty("HealthPct").GetString() ?? "N/A";
                string design = G(r.GetProperty("Design")) ?? "-";
                string full = G(r.GetProperty("Full")) ?? "-";
                string cycle = r.GetProperty("Cycle").GetString() ?? "-";
                string plug = r.GetProperty("Plug").GetString() ?? "-";
                string bright = r.GetProperty("Bright").GetString() ?? "-";
                string plan = r.GetProperty("PowerPlan").GetString() ?? "-";
                string saver = r.GetProperty("BattSaver").GetString() ?? "-";
                double hp = 0;
                double.TryParse(health.Replace("%", ""), out hp);
                Color hc = ColorFor(hp >= 80 ? "ok" : hp >= 60 ? "warn" : "bad");
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.5, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
                AddMetric(g, 0, "电池健康度", health + "%", hc, Bar(hp, hc));
                AddMetric(g, 1, "设计容量", design + " mWh", GrayC, null);
                AddMetric(g, 2, "满充容量", full + " mWh", GrayC, null);
                AddMetric(g, 3, "循环次数", cycle, GrayC, null);
                AddMetric(g, 4, "使用方式", plug, GrayC, null);
                AddMetric(g, 5, "屏幕亮度", bright, GrayC, null);
                AddMetric(g, 6, "电源计划", plan, GrayC, null);
                AddMetric(g, 7, "节电模式", saver, GrayC, null);
                panel.Children.Add(g);
            }
            RootPanel.Children.Add(Card("电池健康", panel));
        }

        private void BuildHabits(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 10 };
            var g = new Grid();
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.5, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
            AddMetric(g, 0, "近 7 天开机次数", r.GetProperty("BootCount").GetInt32().ToString() + " 次", PrimaryC, null);
            AddMetric(g, 1, "累计开机时长", r.GetProperty("TotalH").GetDouble().ToString("0.#") + " 小时", PrimaryC, null);
            AddMetric(g, 2, "平均单次时长", r.GetProperty("AvgH").GetDouble().ToString("0.#") + " 小时", PrimaryC, null);
            AddMetric(g, 3, "本次连续运行", r.GetProperty("UpDays").GetDouble().ToString("0.#") + " 天（" + r.GetProperty("UpH").GetDouble().ToString("0.#") + " 小时）", PrimaryC, null);
            AddMetric(g, 4, "上次开机时间", r.GetProperty("LastBoot").GetString(), GrayC, null);
            panel.Children.Add(g);
            RootPanel.Children.Add(Card("使用习惯", panel));
        }

        private void BuildSuggestions(JsonElement r)
        {
            var panel = new StackPanel { Spacing = 8 };
            foreach (var s in r.GetProperty("Suggestions").EnumerateArray())
            {
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.35, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(2.2, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.1, GridUnitType.Star) });
                string prio = s.GetProperty("Prio").GetString() ?? "";
                string cls = s.GetProperty("Cls").GetString() ?? "ok";
                Color c = ColorFor(cls);
                var badge = new Border
                {
                    Background = new SolidColorBrush(c),
                    CornerRadius = new CornerRadius(4),
                    Padding = new Thickness(6, 2, 6, 2),
                    Child = new TextBlock { Text = prio, FontSize = 11, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromArgb(255, 255, 255, 255)), HorizontalAlignment = HorizontalAlignment.Center }
                };
                badge.VerticalAlignment = VerticalAlignment.Center;
                var txt = new TextBlock { Text = s.GetProperty("Text").GetString(), FontSize = 12, VerticalAlignment = VerticalAlignment.Center, TextWrapping = TextWrapping.Wrap };
                var gain = new TextBlock { Text = s.GetProperty("Gain").GetString(), FontSize = 11, Foreground = new SolidColorBrush(GrayC), TextAlignment = TextAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                Grid.SetColumn(badge, 0); g.Children.Add(badge);
                Grid.SetColumn(txt, 1); g.Children.Add(txt);
                Grid.SetColumn(gain, 2); g.Children.Add(gain);
                panel.Children.Add(g);
            }
            RootPanel.Children.Add(Card("优化建议", panel));
        }

        // Store-style stars: Score/20 per star, half star when remainder >= 10 (max 5). Static, no animation.
        private static System.Collections.Generic.List<UIElement> BuildStars(int score, Color c)
        {
            const double starSize = 34;
            Color emptyC = Color.FromArgb(255, 185, 196, 193);
            double v = score / 20.0;
            int full = (int)Math.Min(5, v + 0.5);
            bool half = (score % 20) >= 10 && full < 5 && full >= 1;
            int empty = 5 - full - (half ? 1 : 0);
            var list = new System.Collections.Generic.List<UIElement>();
            for (int i = 0; i < full; i++) list.Add(StarChar("\u2605", c, starSize));
            if (half) list.Add(HalfStar(c, starSize));
            for (int i = 0; i < empty; i++) list.Add(StarChar("\u2605", emptyC, starSize));
            return list;
        }

        private static FrameworkElement StarChar(string ch, Color c, double size)
        {
            return new TextBlock
            {
                Text = ch,
                FontSize = size,
                Foreground = new SolidColorBrush(c),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Width = size,
                Height = size,
                TextAlignment = TextAlignment.Center
            };
        }

        private static FrameworkElement HalfStar(Color c, double size)
        {
            var g = new Grid { Width = size, Height = size };
            g.Children.Add(StarChar("\u2605", Color.FromArgb(255, 185, 196, 193), size));
            var top = StarChar("\u2605", c, size);
            top.Clip = new RectangleGeometry { Rect = new Windows.Foundation.Rect(0, 0, size / 2.0, size) };
            g.Children.Add(top);
            return g;
        }
        // ---------- helpers ----------
        private static string G(JsonElement e)
        {
            return e.ValueKind switch
            {
                JsonValueKind.String => e.GetString() ?? "",
                JsonValueKind.Number => e.GetRawText(),
                _ => ""
            };
        }

        private Border Card(string title, UIElement content)
        {
            var bar = new Border
            {
                Width = 4,
                Height = 24,
                CornerRadius = new CornerRadius(2),
                Background = new SolidColorBrush(AccentC),
                HorizontalAlignment = HorizontalAlignment.Left,
                VerticalAlignment = VerticalAlignment.Top,
                Margin = new Thickness(0, 2, 0, 0)
            };
            var head = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
            head.Children.Add(bar);
            head.Children.Add(new TextBlock
            {
                Text = title,
                FontSize = 16,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                Foreground = new SolidColorBrush(TextC),
                VerticalAlignment = VerticalAlignment.Center
            });
            var inner = new StackPanel { Spacing = 12 };
            inner.Children.Add(head);
            inner.Children.Add(content);
            return new Border
            {
                Background = new SolidColorBrush(CardC),
                BorderBrush = new SolidColorBrush(LineC),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(18),
                Child = inner
            };
        }

        private Border ScoreChip(string label, int score, Color c)
        {
            return new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(32, c.R, c.G, c.B)),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(12, 6, 12, 6),
                Child = new TextBlock
                {
                    Text = label + " " + score + "分",
                    FontSize = 13,
                    FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                    Foreground = new SolidColorBrush(c)
                }
            };
        }

        private int ScoreDim(JsonElement r, string name)
        {
            if (!r.TryGetProperty("Dims", out var dims)) return 0;
            var key = name switch { "磁盘" => "Disk", "性能" => "Perf", "电池" => "Battery", "清洁" => "Clean", _ => "Disk" };
            if (dims.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.Number)
                return v.GetInt32();
            return 0;
        }

        private string ScoreDimCls(JsonElement r, string name)
        {
            if (!r.TryGetProperty("Dims", out var dims)) return "ok";
            var key = name switch { "磁盘" => "DiskCls", "性能" => "PerfCls", "电池" => "BatteryCls", "清洁" => "CleanCls", _ => "DiskCls" };
            if (dims.TryGetProperty(key, out var v)) return v.GetString() ?? "ok";
            return "ok";
        }

        private Color ColorFor(string? cls)
        {
            return cls switch
            {
                "ok" => OkC,
                "warn" => WarnC,
                "bad" => BadC,
                "primary" => PrimaryC,
                _ => GrayC
            };
        }

        private static TextBlock Note(string? text)
        {
            return new TextBlock
            {
                Text = text ?? "",
                FontSize = 12,
                Foreground = new SolidColorBrush(GrayC),
                TextWrapping = TextWrapping.Wrap
            };
        }

        private static Grid Bar(double pct, Color c)
        {
            pct = Math.Clamp(pct, 0, 100);
            var g = new Grid { Height = 10 };
            var fill = new Grid();
            fill.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(pct, GridUnitType.Star) });
            fill.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(Math.Max(0, 100 - pct), GridUnitType.Star) });
            var f0 = new Border { Background = new SolidColorBrush(c), CornerRadius = new CornerRadius(5), HorizontalAlignment = HorizontalAlignment.Stretch };
            var f1 = new Border { Background = new SolidColorBrush(LineC), CornerRadius = new CornerRadius(5), HorizontalAlignment = HorizontalAlignment.Stretch };
            Grid.SetColumn(f0, 0); fill.Children.Add(f0);
            Grid.SetColumn(f1, 1); fill.Children.Add(f1);
            g.Children.Add(fill);
            g.VerticalAlignment = VerticalAlignment.Center;
            return g;
        }

        private static void AddMetric(Grid g, int row, string label, string value, Color c, FrameworkElement? bar)
        {
            g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var l = new TextBlock { Text = label, FontSize = 12, Foreground = new SolidColorBrush(GrayC), VerticalAlignment = VerticalAlignment.Center };
            var v = new TextBlock { Text = value, FontSize = 13, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Foreground = new SolidColorBrush(c), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetRow(l, row); Grid.SetColumn(l, 0); g.Children.Add(l);
            if (bar != null) { Grid.SetRow(bar, row); Grid.SetColumn(bar, 1); g.Children.Add(bar); }
            Grid.SetRow(v, row); Grid.SetColumn(v, 2); g.Children.Add(v);
        }
    }
}
