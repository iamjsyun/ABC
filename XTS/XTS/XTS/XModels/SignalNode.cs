using DevExpress.Mvvm;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

namespace XTS.XModels;

public class SignalNode : BindableBase
{
    private XSignal _masterSignal = null!;
    public XSignal MasterSignal
    {
        get => _masterSignal;
        set => SetProperty(ref _masterSignal, value, nameof(MasterSignal));
    }

    private ObservableCollection<XSignal> _gridSignals = new ObservableCollection<XSignal>();
    public ObservableCollection<XSignal> GridSignals
    {
        get => _gridSignals;
        set => SetProperty(ref _gridSignals, value, nameof(GridSignals));
    }

    private bool _isExpanded = true;
    public bool IsExpanded
    {
        get => _isExpanded;
        set => SetProperty(ref _isExpanded, value, nameof(IsExpanded));
    }

    public string GroupGid
    {
        get
        {
            // [sid 구조] CNO(4)-yyMMddHH(8)-SNO(2)+GNO(2)-dir(1)-type(1)
            // 그룹 식별을 위해 CNO-yyMMddHH-SNO (약 15~16자) 사용
            if (MasterSignal != null && !string.IsNullOrEmpty(MasterSignal.sid) && MasterSignal.sid.Length >= 15)
            {
                // SNO(2) 다음의 '+' 이전까지 추출
                int plusIdx = MasterSignal.sid.IndexOf('+');
                if (plusIdx > 0) return MasterSignal.sid.Substring(0, plusIdx);
                return MasterSignal.sid;
            }
            return "GROUP";
        }
    }

    public IEnumerable<XSignal> AllSignalsInOrder
    {
        get
        {
            var list = new List<XSignal>();
            if (MasterSignal != null)
            {
                list.Add(MasterSignal);
            }
            foreach(var s in GridSignals) 
            {
               if(!list.Contains(s)) list.Add(s);
            }
            return list.OrderBy(s => s.gno);
        }
    }

    public SignalNode(XSignal masterSignal)
    {
        MasterSignal = masterSignal;
    }
}
