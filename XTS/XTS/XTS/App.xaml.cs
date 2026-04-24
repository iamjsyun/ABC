using System.Configuration;
using System.Data;
using System.Windows;

namespace XTS
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            try
            {
                // XTG (XTS) 핵심 서비스 초기화 및 시작
                XTSStartup.Initialize();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"시스템 초기화 중 오류가 발생했습니다: {ex.Message}", "오류", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

}
