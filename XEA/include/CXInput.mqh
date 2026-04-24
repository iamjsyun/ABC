#ifndef CX_INPUT_MQH
#define CX_INPUT_MQH

#include <Object.mqh>

enum ENUM_DIR_MODE {
    DIR_MODE_STOP = 0,
    DIR_MODE_RUN  = 1
};

// [v8.5] Strategic Grid Level Configuration
struct CXGridLevel {
    int    gno;             
    string open_id;         
    string open_args;       
    string close_id;        
    string close_args;      
    bool   is_valid;        
    
    // v8.5 Extended Parameters
    int    type;
    double lot;             
    double offset;
    int    tb_start;
    int    tb_step;
    int    tb_limit;          
};

struct CXDirectionSettings {
    ENUM_DIR_MODE Mode;
    CXGridLevel   Grids[15]; // [v2.9.30] 5 -> 15 (G0 ~ G14)
    int           MaxGrid;
};

class CXInput : public CObject
{
public:
    long   MagicNumber;
    string         DbName;
    bool           UseRemoteLogger;
    string         RemoteLogger;

    bool           IsRunning;
    uint   TrailReversal;

    CXDirectionSettings BuySettings;
    CXDirectionSettings SellSettings;

    CXInput() : MagicNumber(1001), DbName("AXGS.db"), RemoteLogger(""), IsRunning(false), TrailReversal(20) 
    {
        BuySettings.MaxGrid = 0;
        SellSettings.MaxGrid = 0;
        for(int i=0; i<15; i++) { // [v2.9.30] 15 levels
            BuySettings.Grids[i].is_valid = false;
            BuySettings.Grids[i].lot = 0.01;
            BuySettings.Grids[i].type = 1; // TYPE_MARKET
            BuySettings.Grids[i].offset = 0;
            BuySettings.Grids[i].tb_start = 0;
            BuySettings.Grids[i].tb_step = 0;
            BuySettings.Grids[i].tb_limit = 0;
            
            SellSettings.Grids[i].is_valid = false;
            SellSettings.Grids[i].lot = 0.01;
            SellSettings.Grids[i].type = 1; // TYPE_MARKET
            SellSettings.Grids[i].offset = 0;
            SellSettings.Grids[i].tb_start = 0;
            SellSettings.Grids[i].tb_step = 0;
            SellSettings.Grids[i].tb_limit = 0;
        }
    }

    void ParseLevel(int dir, int idx, string raw)
    {
        if(raw == "" || idx < 0 || idx >= 15) return; 
        
        string parts[];
        int count = StringSplit(raw, ',', parts);
        if(count < 5) return; 

        if(dir == 1) {
            BuySettings.Grids[idx].gno        = (int)StringToInteger(parts[0]);
            BuySettings.Grids[idx].open_id    = parts[1];
            BuySettings.Grids[idx].open_args  = parts[2];
            BuySettings.Grids[idx].close_id   = parts[3];
            BuySettings.Grids[idx].close_args = parts[4];
            StringTrimLeft(BuySettings.Grids[idx].open_id); StringTrimRight(BuySettings.Grids[idx].open_id);
            StringTrimLeft(BuySettings.Grids[idx].close_id); StringTrimRight(BuySettings.Grids[idx].close_id);
            BuySettings.Grids[idx].is_valid   = true;
            
            string args[];
            int argCount = StringSplit(BuySettings.Grids[idx].open_args, ';', args);
            if(argCount >= 7) {
                BuySettings.Grids[idx].gno      = (int)StringToInteger(args[0]);
                BuySettings.Grids[idx].type     = (int)StringToInteger(args[1]);
                BuySettings.Grids[idx].lot      = StringToDouble(args[2]);
                BuySettings.Grids[idx].offset   = StringToDouble(args[3]);
                BuySettings.Grids[idx].tb_start = (int)StringToInteger(args[4]);
                BuySettings.Grids[idx].tb_step  = (int)StringToInteger(args[5]);
                BuySettings.Grids[idx].tb_limit = (int)StringToInteger(args[6]);
            } else if(argCount >= 2) {
                BuySettings.Grids[idx].tb_limit = (int)StringToInteger(args[0]);
                BuySettings.Grids[idx].lot      = StringToDouble(args[1]);
            }
            if(idx > BuySettings.MaxGrid) BuySettings.MaxGrid = idx;
        } else {
            SellSettings.Grids[idx].gno        = (int)StringToInteger(parts[0]);
            SellSettings.Grids[idx].open_id    = parts[1];
            SellSettings.Grids[idx].open_args  = parts[2];
            SellSettings.Grids[idx].close_id   = parts[3];
            SellSettings.Grids[idx].close_args = parts[4];
            StringTrimLeft(SellSettings.Grids[idx].open_id); StringTrimRight(SellSettings.Grids[idx].open_id);
            StringTrimLeft(SellSettings.Grids[idx].close_id); StringTrimRight(SellSettings.Grids[idx].close_id);
            SellSettings.Grids[idx].is_valid   = true;
            
            string args[];
            int argCount = StringSplit(SellSettings.Grids[idx].open_args, ';', args);
            if(argCount >= 7) {
                SellSettings.Grids[idx].gno      = (int)StringToInteger(args[0]);
                SellSettings.Grids[idx].type     = (int)StringToInteger(args[1]);
                SellSettings.Grids[idx].lot      = StringToDouble(args[2]);
                SellSettings.Grids[idx].offset   = StringToDouble(args[3]);
                SellSettings.Grids[idx].tb_start = (int)StringToInteger(args[4]);
                SellSettings.Grids[idx].tb_step  = (int)StringToInteger(args[5]);
                SellSettings.Grids[idx].tb_limit = (int)StringToInteger(args[6]);
            } else if(argCount >= 2) {
                SellSettings.Grids[idx].tb_limit = (int)StringToInteger(args[0]);
                SellSettings.Grids[idx].lot      = StringToDouble(args[1]);
            }
            if(idx > SellSettings.MaxGrid) SellSettings.MaxGrid = idx;
        }
    }
};

#endif
