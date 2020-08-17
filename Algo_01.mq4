//+------------------------------------------------------------------+
//|                                                      Algo_01.mq4 |
//|                                         Copyright 2019, Andre Le |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Andre Le"
#property link      "https://www.mql5.com"
#property version   "1.01"
#property strict

extern ENUM_TIMEFRAMES MACrossSignalTimeFrame=PERIOD_H1;
extern string MACrossIndiPath = "CustomIndi\\Trend and stochastics\\MACrossIndi";
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
//Adjust for 5 digits brokers pips:
if(Digits==3 || Digits ==5)
      pips*=10;
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //---

   //specify lot size
   switch(LotSizeFactor)
        {
         case Standard: EALotSizeFactor = 1; break;
         case Mini:    EALotSizeFactor = 0.1 ; break;
         case Micro:   EALotSizeFactor = 0.01 ; break;
        }
  }
//+------------------------------------------------------------------+
//declare output array
struct MACrossSignalDict {int CrossSignal; int CrossTime; }; //initialize MAcross signal output data dictionary
MACrossSignalDict MACrossSignalData={0,0}; 
int TradeSignals(string sym)
{
   //Check if various signals is valid
   MACrossSignal(sym,0); //<-- check MAcross
   
   
   //Call order execution if all signals is valid
   
}


//+------------------------------------------------------------------+
//| OrderEntry                                                                 |
//+------------------------------------------------------------------+
void OrderEntry(string sym, ENUM_TIMEFRAMES tf, int direction, bool TradingAllow)
  {
   double sAsk = MarketInfo(sym,MODE_ASK); double sBid = MarketInfo(sym,MODE_BID);
   double prevClose = iClose(sym, tf, 1); double prevOpen = iOpen(sym, tf, 1);

   //convert risk and reward percentage to no. of pips
   double Equity = AccountEquity(); //get the account equity
   double RiskedAmt = Equity*RiskPcnt*0.01; //computing the risking amount in dollar term
   
   // Determine the StopLoss of Buy/Sell order base on the Highest/Lowest Candle:
   int buyStopCandle = iLowest(sym,0,1,CandlesBack,1);
   int sellStopCandle = iHighest(sym,0,2,CandlesBack,1);
   double buyStopPrice = iLow(sym,0,buyStopCandle)-PadAmountTrailSL*pips;
   double sellStopPrice = iHigh(sym,0,sellStopCandle)+PadAmountTrailSL*pips;

   //Determin the TakeProfit of the order base on R:R ratio
   double buyProfitPrice = sAsk+((sAsk-buyStopPrice)*Reward_ratio);
   double sellProfitPrice = sBid-((sellStopPrice-sBid)*Reward_ratio);
   double EntryPrice, bsl, btp, ssl, stp;
   string Order_Type;


   int buyTicket, sellTicket;
   //================BUY order==============
   if(direction==0)
     {
      //Calculat the lotsize: Risked Amount / no. of pips to get $$ amt risked per pips
      if(UseLimitOrder==false)EntryPrice=sAsk;
      else EntryPrice=prevOpen; //use prev open price in case of LimitOrder
      bsl = buyStopPrice;
      btp = buyProfitPrice;

      OrderLotSize=NormalizeDouble(RiskedAmt/((EntryPrice-bsl)/pips),2) * EALotSizeFactor ; //10 is the miniLot (0.1 Lot), 100 is the microLot (0.01 Lot)
      //Print("LotSize ", LotSize);

      // Main BUY trade execution part-----------------------
      if(OpenOrdersThisPair(sym,0)<=NoBUYActiveTrade)            //--Check number of current BUY active orders
            if(TradingAllow) //If trading is allowed
              {
              //MARKET BUY ORDER
               if(UseLimitOrder==false && 
                   IsThereRecentPosition(sym,OP_BUY,HourFromLastPosition)==false //check if there is not a recent BUY order opened;
                  ) 
                 {
                  buyTicket=OrderSend(sym,OP_BUY,LotSize,EntryPrice,3,bsl,btp,"MAx EA v2-BUY MarketOrder",MagicNumber,
                                      0,clrGreen);
                  Order_Type = "OP_BUY";
                 }
               else //FOR LIMIT BUY ORDER
                 {
                  if(OpenOrdersThisPair(sym,OP_BUYLIMIT)<=NoBUYPendingTrade
                     && IsThereRecentPosition(sym,OP_BUYLIMIT,HourFromLastPosition)==false
                     )
                     buyTicket=OrderSend(sym,OP_BUYLIMIT,LotSize,EntryPrice,3,bsl,btp,"MAx EA v2-BUY LimOrder",MagicNumber,
                                         0,clrGreen);
                  Order_Type = "OP_BUYLIMIT";
                 }
               if(buyTicket>0) LastOrderCandle = iBars(sym,0);
               //Send BUY ORDER notification
               SendPushNotification(OrderExecNotif, EntryPrice, bsl, btp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
               Print("[OrderEntry] ", Order_Type, " ", ", buyTicket:", buyTicket," , LotSize: ",LotSize, " EntryPrice: ",EntryPrice," SL: ", bsl, " TP: ",btp);
               //Print("LastOrderCandle is ", LastOrderCandle, "LastOrderGap is ", LastOrderGap);
              }
               else //if trading is NOT allowed (Signal Only)
              {
               SendPushNotification(SignalNotif, EntryPrice, bsl, btp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
              }
              
      //+-------------------------------------------------
     }
//Note: For EA, cannot use "NULL" like in indicator function

//--------sell order----------------
   if(direction==1) 
     {
         if(UseLimitOrder==false) EntryPrice=sBid;
         else EntryPrice=sBid + LimOrder_GapFromMarketPrice*pips;
         bsl = sellStopPrice;
         btp = sellProfitPrice;

      LotSize=NormalizeDouble(RiskedAmt/((ssl-EntryPrice)/pips),2) * EALotSizeFactor * EAposize.SELLscalefactor; // 
      //Print("[OrderEntry] LotSize: ",LotSize, " EntryPrice: ",EntryPrice," SL: ", ssl, " TP: ",stp);

      //check how many current opened Sell orders
      if(OpenOrdersThisPair(sym,1)<=NoSELLActiveTrade)
            if(TradingAllow) //If trading is allowed
              {
               if(UseLimitOrder==false
                  &&  IsThereRecentPosition(sym,OP_SELL,HourFromLastPosition)==false //check if there is not a recent Sell order opened;

                  ) //if not using limit order\
                 {
                  sellTicket= OrderSend(sym,OP_SELL,LotSize,EntryPrice,3,ssl,stp,"MAx EA v2-SELL MarketOrder",MagicNumber,
                                        0,clrRed);
                  Order_Type = "OP_SELL";
                 }
               else
                 {
                  if(OpenOrdersThisPair(sym,OP_SELLLIMIT)<=NoSELLPendingTrade
                     && IsThereRecentPosition(sym,OP_SELLLIMIT,HourFromLastPosition)==false
                     )
                     sellTicket= OrderSend(sym,OP_SELLLIMIT,LotSize,EntryPrice,3,ssl,stp,"MAx EA v2-SELL LimOrder",MagicNumber,
                                           0,clrRed);
                  Order_Type = "OP_SELLLIMIT";
                 }
               if(sellTicket>0)
                  LastOrderCandle = iBars(sym,0);

               //Send notification
               SendPushNotification(OrderExecNotif, EntryPrice, ssl, stp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
               Print("[OrderEntry] ", Order_Type, " ",", sellTicket:", sellTicket," , LotSize: ",LotSize, " EntryPrice: ",EntryPrice," SL: ", bsl, " TP: ",btp);
              }
                  else //if trading is NOT allowed (Signal Only)
              {
               SendPushNotification(SignalNotif, EntryPrice, ssl, stp, sym, Order_Type,Time[0],1,MobileNotification, EmailNotification);
              }
     }
  } //end OrderEntry




//--setting vars for FastMA------
extern int FastMA=5; extern int FastMAShift=0; extern int FastMAMethod=1; extern int FastMAAppliedTo=0;
//--setting vars for SlowMA------
extern int SlowMA=21; extern int SlowMAShift=0; extern int SlowMAMethod=1; extern int SlowMAAppliedTo=0;


int MACrossSignal(string sym, int shift)
{

   //Getting the signal from MACrossIndicator
   // 1. CrossSignal
   MACrossSignalData.CrossSignal = iCustom(sym,MACrossSignalTimeFrame,MACrossIndiPath,3,
   FastMA, FastMAShift, FastMAMethod, FastMAAppliedTo, //FastMA params
   SlowMA, SlowMAShift, SlowMAMethod, SlowMAAppliedTo, //SlowMA params   
   shift);
   // 2. CrossTime
   MACrossSignalData.CrossTime = iCustom(sym,MACrossSignalTimeFrame,MACrossIndiPath,4,
   FastMA, FastMAShift, FastMAMethod, FastMAAppliedTo, //FastMA params
   SlowMA, SlowMAShift, SlowMAMethod, SlowMAAppliedTo, //SlowMA params 
   shift);
   
   //---------------
   return(0);
}

//--setting vars for SlowMA------
extern int SlowMA=21;
extern int SlowMaShift=0;
extern int SlowMaMethod=1;
extern int SlowMaAppliedTo=0;