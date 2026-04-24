using System;
using DevExpress.Mvvm;
using DevExpress.Xpo;

namespace XTS.XModels
{
    public class XGridProfile : BindableBase
    {
        public int cno { get; set; }
        public int dir { get; set; } // 1: Buy, 2: Sell
        public int gno { get; set; }
        public int type { get; set; } // 1:Market, 2:Limit_M, 3:Trail_M, 4:Limit_P, 5:Trail_P (v7.5)
        public double offset { get; set; }
        public double lot { get; set; }
        public double tp { get; set; }
        public double sl { get; set; }
        public int ts_trigger { get; set; } = 500;
        public int ts_step { get; set; } = 100;
        public int gap_min { get; set; } = 200;

        public XGridProfile Clone()
        {
            return new XGridProfile
            {
                cno = this.cno,
                dir = this.dir,
                gno = this.gno,
                type = this.type,
                offset = this.offset,
                lot = this.lot,
                tp = this.tp,
                sl = this.sl,
                ts_trigger = this.ts_trigger,
                ts_step = this.ts_step,
                gap_min = this.gap_min
            };
        }
    }
}

namespace XTS.XModels.DB
{
    [Persistent("grid_profiles")]
    public class XpoGridProfile : XPLiteObject
    {
        public XpoGridProfile(Session session) : base(session) { }

        [Key(true)]
        public int Oid { get; set; }

        private int _cno;
        [Indexed("dir", "gno", Unique = true)]
        public int cno { get => _cno; set => SetPropertyValue(nameof(cno), ref _cno, value); }

        private int _dir;
        public int dir { get => _dir; set => SetPropertyValue(nameof(dir), ref _dir, value); }

        private int _gno;
        public int gno { get => _gno; set => SetPropertyValue(nameof(gno), ref _gno, value); }

        private int _type;
        public int type { get => _type; set => SetPropertyValue(nameof(type), ref _type, value); }

        private double _offset;
        public double offset { get => _offset; set => SetPropertyValue(nameof(offset), ref _offset, value); }

        private double _lot;
        public double lot { get => _lot; set => SetPropertyValue(nameof(lot), ref _lot, value); }

        private double _tp;
        public double tp { get => _tp; set => SetPropertyValue(nameof(tp), ref _tp, value); }

        private double _sl;
        public double sl { get => _sl; set => SetPropertyValue(nameof(sl), ref _sl, value); }

        private int _ts_trigger;
        public int ts_trigger { get => _ts_trigger; set => SetPropertyValue(nameof(ts_trigger), ref _ts_trigger, value); }

        private int _ts_step;
        public int ts_step { get => _ts_step; set => SetPropertyValue(nameof(ts_step), ref _ts_step, value); }

        private int _gap_min;
        public int gap_min { get => _gap_min; set => SetPropertyValue(nameof(gap_min), ref _gap_min, value); }
    }
}
