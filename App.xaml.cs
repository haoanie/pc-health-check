using System;
using Microsoft.UI.Xaml;

namespace TiJianWinUI
{
    public partial class App : Application
    {
        private Window? _window;
        public App()
        {
            InitializeComponent();
            UnhandledException += (s, e) => { };
        }
        protected override void OnLaunched(LaunchActivatedEventArgs args)
        {
            _window = new MainWindow();
            _window.Activate();
        }
    }
}