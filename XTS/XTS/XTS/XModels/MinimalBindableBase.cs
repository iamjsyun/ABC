using System.ComponentModel;
using System.Runtime.CompilerServices;

// These using statements are for types that might not be available.
// If they cause errors, they can be replaced with dummy implementations.

namespace XTS.XModels;

// --- Dummy/Minimal Implementations to satisfy dependencies ---

// A minimal replacement for DevExpress.Mvvm.BindableBase
public abstract class MinimalBindableBase : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
    protected bool SetProperty<T>(ref T storage, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(storage, value)) return false;
        storage = value;
        OnPropertyChanged(propertyName);
        return true;
    }
}
