
using DevExpress.Mvvm;
using ILogger = NLog.ILogger;
using IMessenger = DevExpress.Mvvm.IMessenger;

namespace XTS.XModels;

// --- Copied and Adapted Classes from XApp ---

public abstract class XObject : MinimalBindableBase
{
    public XParameter param { get; private set; }
    // For simplicity, nlog and messenger are directly instantiated or nullable
    // In a real scenario, these would be injected.
    public ILogger nlog { get; set; } = NLog.LogManager.GetCurrentClassLogger();
    public IMessenger messenger { get; set; } = Messenger.Default;

    private long _CID;
    public long CID
    {
        get => _CID;
        protected set => SetProperty(ref _CID, value, nameof(CID));
    }

    protected XObject(XParameter param)
    {
        this.param = param;
    }

    protected XObject(XParameter param, long cid)
    {
        this.param = param;
        this.CID = cid;
    }

    public virtual void Start() { }
    public virtual void Stop() { }
}
