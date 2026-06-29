* @ValidationCode : MjotMjExNzk2MDI4MzpDcDEyNTI6MTU4ODA2Njk2MjU3NTp2a3ByYXRoaWJhOjEwOjA6MDoxOmZhbHNlOk4vQTpERVZfMjAyMDA0LjIwMjAwNDAyLTA1NDk6MTM1OjEzNQ==
* @ValidationInfo : Timestamp         : 28 Apr 2020 15:12:42
* @ValidationInfo : Encoding          : Cp1252
* @ValidationInfo : User Name         : vkprathiba
* @ValidationInfo : Nb tests success  : 10
* @ValidationInfo : Nb tests failure  : 0
* @ValidationInfo : Rating            : N/A
* @ValidationInfo : Coverage          : 135/135 (100.0%)
* @ValidationInfo : Strict flag       : true
* @ValidationInfo : Bypass GateKeeper : false
* @ValidationInfo : Compiler Version  : DEV_202004.20200402-0549
* @ValidationInfo : Copyright Temenos Headquarters SA 1993-2021. All rights reserved.

*------------------------------------------------------------------------------------------------------------------------------------------------------*
$PACKAGE AA.MarketingCatalogue
SUBROUTINE AA.CALC.PAYMENT.AMOUNT(Product, PrincipalAmount, ArrCcy, StartDate, OutDetails)

*** <region name= Program Description>
***
* Program Description
* Nofile Enquiry routine to return the installment amount and total payment amount to be paid
* during the entire the term period for a given Product
* Accepts a product with a sample Term amount and read the product condition records to get the Term,
* Interest and Payment Schedule record.
*   This routine is a 'Wrapper' to  get Payment Amount from AA.MC.CALCULATE.PAYMENT.SCHEDULE as described below:
*   AA.MC.CALCULATE.PAYMENT.SCHEDULE is itself simply a wrapper for the existing EB.CALC.PAYMENT.SCHEDULE
*   from which it will get the following installment and Total installment amount to be paid during the
*   lifetime of the loan.
*------------------------------------------------------------------------------------------------------------------------------------------------------*
* @uses I_ENQUIRY.COMMON
* @class AA.MarketingCatalogue
* @package retaillending.AA
* @stereotype subroutine
* @author vkprathiba@temenos.com
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*
*** <region name= Arguments>
*** <desc>Input and output arguments required for the sub-routine</desc>
* Arguments
*
* Input arguments
*
* @Param    Product          Valid Product Id
* @Param    PrincipalAmount  Principal Amount (Term Amount)
* @Param    ArrCcy           Product currency. Default is local currency
*
* Output arguments
*
* @Param    OutDetails       Returns Interest Effective rate, Installment Amount and Total Payment Amount
*
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*
*** <region name= Modification History>
***
* Modification History :
*
* 02/04/20 - Enhan : 3657293
*            Task  : 3657296
*            NoFile routine to return installment and Total Payment amount for a selected product with a transaction amount
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*

*** <region name= Inserts>
*** <desc> </desc>
    
    $USING EB.SystemTables
    $USING AA.ProductFramework
    $USING AA.PaymentSchedule
    $USING AA.TermAmount
    $USING AA.Interest
    $USING AA.Framework
    $USING EB.API
    
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= Main Processing>
*** <desc> </desc>
   
    GOSUB Initialise
    GOSUB GetProductDetails
    GOSUB GetSchedule
    GOSUB ValidateDetails
    IF NOT(ErrorMessage) THEN
        GOSUB GetInterestRate
        GOSUB CalcPaymentAmount     ;* Get the Payment installment amount
    END ELSE
        OutDetails = ErrorMessage
    END
    AA.Framework.setAaPropertyClassList(SaveProperty)   ;* Restore the property class common
    
RETURN

*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= Initialise>
*** <desc>Initialise Program Output  Parameters </desc>
Initialise:
    
    EffectiveDate = EB.SystemTables.getToday()  ;* Today Date
    ErrorMessage = ''
    OutDetails = ''
    
RETURN

*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= GetProductDetails>
*** <desc>Get the details of the Product</desc>
GetProductDetails:
    
    RProduct = ''
    RetErr = ''
    TermProperty = ''
    PaymentSchedProperty = ''
    InterestProperty = ''
    AA.ProductFramework.GetPublishedRecord('PRODUCT', '', Product, '', RProduct, RetErr)    ;* Get the Published product record
    
    SaveProperty = ''
    SaveProperty = AA.Framework.getAaPropertyClassList()
    AA.Framework.setAaPropertyClassList('')     ;* Clear the Property Class common
    
    AA.ProductFramework.GetPropertyName(RProduct, 'TERM.AMOUNT', TermProperty)   ;* Fetch the Term Amount Property
    AA.ProductFramework.GetPropertyName(RProduct, 'PAYMENT.SCHEDULE', PaymentSchedProperty)   ;* Fetch the Payment Schedule Property
    AA.ProductFramework.GetPropertyName(RProduct, 'INTEREST', InterestProperty)   ;* Fetch the Interest Property
    
*** Get the Properties condition record
    
    PRODUCT.OR.PROPERTY = 'PROPERTY'
    ValErr = ''
    RSchedule = ''
    
    AA.ProductFramework.GetProductPropertyRecord(PRODUCT.OR.PROPERTY, '', Product, TermProperty, '', ArrCcy, '', EffectiveDate, TermConditionRecords, ValErr)
    AA.ProductFramework.GetProductPropertyRecord(PRODUCT.OR.PROPERTY, '', Product, InterestProperty, '', ArrCcy, '', EffectiveDate, IntConditionRecords, ValErr)
    AA.ProductFramework.GetProductPropertyRecord(PRODUCT.OR.PROPERTY, '', Product, PaymentSchedProperty, '', ArrCcy, '', EffectiveDate, InScheduleConditionRecords, ValErr)
    RSchedule = InScheduleConditionRecords
    
    GOSUB FetchProductConditions    ;* Get the Conditions of the Properties

RETURN

*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= FetchProductConditions>
*** <desc>Get the Conditions of the Properties</desc>
FetchProductConditions:
    
    Term = ''
    PsProperty = ''
    
    Term = TermConditionRecords<AA.TermAmount.TermAmount.AmtTerm>   ;* Fetch term
    PsProperty = InScheduleConditionRecords<AA.PaymentSchedule.PaymentSchedule.PsProperty>  ;* Fetch Schedule Properties
    
    FIND InterestProperty IN PsProperty SETTING FmPos,VmPos,SmPos THEN      ;* Check whether the interest property is scheduled
        InScheduleConditionRecords<AA.PaymentSchedule.PaymentSchedule.PsStartDate,VmPos> = StartDate    ;* If scheduled, pass the start date
        Frequency = InScheduleConditionRecords<AA.PaymentSchedule.PaymentSchedule.PsPaymentFreq,VmPos>  ;* Fetch Frequency
        NumPayments = InScheduleConditionRecords<AA.PaymentSchedule.PaymentSchedule.PsNumPayments,VmPos,1>  ;* Fetch Num Payments
    END
    
    IF NOT(Term) THEN   ;* If Term is not passed
        EB.SystemTables.setComi(StartDate:Frequency)    ;* Set Comi with start date along with frequency

        LOOP
            EB.API.Cfq()    ;* Get the Next cycle date using the comi

            NoDates += 1
            ExitFlag = ''
            NextCycleDate = EB.SystemTables.getComi()[1,8]  ;* Fetch next date
    
            IF NoDates GE NumPayments THEN      ;* Loop until the no of cycle date matches the num payments
                ExitFlag = 1
            END ELSE
                ReturnEndDate = NextCycleDate   ;* Fetch the last cycle/payment date
            END
        UNTIL ExitFlag
        REPEAT
    
        YDays = 'C'     ;* To get calendar date
        EB.API.Cdd('', EffectiveDate, ReturnEndDate, YDays)     ;* Get the day difference between today and payment last date
        Term = YDays:'D'    ;* Form the term
    END
    
RETURN
 
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= GetSchedule>
*** <desc>Get Schedule details</desc>
GetSchedule:
    
*** Call the Load routine to decompose incoming Condition records and to load what Target routine and this routine needs to Commons

    ReturnError=''
    PaymentDates =''
    PaymentDateTypes=''
    CalculationType=''
    PaymentFrequency=''
    NumberOfPayments=''
    EffDate = ''
    EffDate<1> = EffectiveDate  ;* Pass Effective date
    EffDate<2> = StartDate      ;* Pass Start date to calculate the frequency of payment dates based on the start date
    AA.MarketingCatalogue.McLoadPaymentScheduleDetails(EffDate, Term, InScheduleConditionRecords, PaymentDates, PaymentDateTypes, CalculationType, PaymentFrequency, NumberOfPayments, ReturnError)
 
 RETURN
  
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= GetInterestRate>
*** <desc>Get the Product Interest Rate</desc>
GetInterestRate:
    
    InstRate = ''
    RateDayBasis = ''
    Rates = ''
    RateDayBasis = IntConditionRecords<AA.Interest.Interest.IntDayBasis>    ;* Fetch Interest Basis
    TierRates = IntConditionRecords<AA.Interest.Interest.IntFixedRate>
    
    BEGIN CASE
        
        CASE IntConditionRecords<AA.Interest.Interest.IntRateTierType> EQ 'SINGLE'  ;* Directly fetch the fixed interest rate
            InstRate = TierRates   ;* Fetch Interest Rate
        CASE IntConditionRecords<AA.Interest.Interest.IntRateTierType> EQ 'LEVEL'   ;* If its level
            TotTierRates = DCOUNT(TierRates,@VM)    ;* fetch the number of levels
            IF TotTierRates GT 1 THEN
                FOR TierCnt = 1 TO TotTierRates
                    TierPercent = IntConditionRecords<AA.Interest.Interest.IntTierPercent,TierCnt>  ;* get the current tier percentage
                    TierAmount = IntConditionRecords<AA.Interest.Interest.IntTierAmount,TierCnt>    ;* get the current tier amount
                    LevelEffectiveRate = TierRates<1,TierCnt>   ;* effective interest rate for this level

                    GOSUB DetermineCurrentTierAmount
                    
                    IF PrincipalAmount LE CurrentTierAmount THEN
                        InstRate = LevelEffectiveRate   ;* if principa amounts falls in this level, return the corresponding interest rate
                        TierCnt = TotTierRates  ;* no need to process rest of the loop
                    END ELSE
                        IF TierCnt EQ TotTierRates THEN
                            WeigInstRatehtedIntRate = LevelEffectiveRate    ;* Default the last rate if the amt doesnt fall under any of the level
                        END
                    END
                NEXT TierCnt
            END ELSE
                InstRate = TierRates   ;* Fetch Fixed Interest Rate if the interest rate exists only in 1 level
            END
    END CASE
   
RETURN
  
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= DetermineCurrentTierAmount>
*** <desc> Fetch the amount for current tier</desc>
DetermineCurrentTierAmount:
   
    BEGIN CASE
        CASE TierPercent
            CurrentTierAmount = (TierPercent/100)*PrincipalAmount   ;*  what is the amount applicable for this level when % given
        CASE TierAmount
            CurrentTierAmount = TierAmount  ;* in case tier amount given, directly take it as the level amount
    END CASE
            
RETURN

*** </region>
*-----------------------------------------------------------------------------
*** <region name= ValidateDetails>
*** <desc>By Now we should have all we need , Confirm to continue , else Return error </desc>
ValidateDetails:
    
    BEGIN CASE
        CASE NOT(InScheduleConditionRecords)
            ErrorMessage = 'AA-CONDITION.IS.REQUIRED.FOR.PAYMENT.CALCULATION'
        CASE NOT(PrincipalAmount)
            ErrorMessage = 'AA-LOAN.AMOUNT.IS.REQUIRED.FOR.PAYMENT.CALCULATION' ;* Return Error Message
        CASE NOT(PaymentDates)
            ErrorMessage = 'AA-PAYMENT.DATES.IS.REQUIRED.FOR.PAYMENT.CALCULATION' ;* Return Error Message
        CASE NOT(CalculationType)
            ErrorMessage = 'AA-CALCULATION.TYPE.IS.REQUIRED.FOR.PAYMENT.CALCULATION' ;* Return Error Message
    END CASE
       
RETURN

*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
*** <region name= CalcPaymentAmount>
*** <desc> Main processing logic is included here </desc>
CalcPaymentAmount:

* Fetch the installment amount, Payment dates for the given Payment amount
    PaymentAmount = ''  ;* Initialise ouput parameter
    ReturnError = ''
    AA.MarketingCatalogue.McCalculatePaymentSchedule(InScheduleConditionRecords, Currency, EffectiveDate, PaymentDates, PaymentDateTypes, CalculationType, PaymentFrequency, NumberOfPayments, InstRate, RateDayBasis, RateRoundingRule, PrincipalAmount, Term, PaymentAmount, ResidualAmount, ReturnError)
    
    IF ReturnError THEN
        OutDetails<-1> = ReturnError    ;* Assign returned error to Final Error
    END ELSE        ;* Return the details rate, installment amount and total payment amount
        OutDetails<-1> = InstRate
        OutDetails<-1> = PaymentAmount
        OutDetails<-1> = PaymentAmount*NumPayments      ;* Total Payment amount - installment amount * no of payments(no of times to pay an installment)
    END
    
RETURN
     
*** </region>
*------------------------------------------------------------------------------------------------------------------------------------------------------*
END
