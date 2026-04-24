using System.IO;
using System.Windows;
using XTS.XModels;

namespace XTS.WPF
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        public static XParameter Param { get; private set; } = null!;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // 1. 설정 파일 경로 결정 (_config 폴더 내부)
            string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "_config", "config.json");

            try
            {
                // 2. Core Engine 초기화 (XTSStartup 활용)
                // static Initialize 메서드를 통해 XParameter 및 내부 서비스(DB 등)를 모두 로드함
                Param = XTSStartup.Initialize(configPath);
                Param.nlog.Info("XTG Engine initialized successfully.");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"XTG Engine 초기화 실패:\n{ex.Message}", "Fatal Error", MessageBoxButton.OK, MessageBoxImage.Error);
                Shutdown();
                return;
            }

            // 3. 메인 윈도우 생성
            var mainWindow = new MainWindow();
            mainWindow.Show();
        }
    }
}
