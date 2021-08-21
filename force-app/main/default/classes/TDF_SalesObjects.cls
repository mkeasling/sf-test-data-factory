@IsTest
public with sharing class TDF_SalesObjects extends TDF.Provider {
    public override sObject call(
        String methodKey,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        switch on methodKey {
            when 'createAccount' {
                return createAccount(fieldVals, doDml);
            }
            when 'createOpportunity' {
                return createOpportunity(fieldVals, doDml);
            }
        }
        throw new MissingMethodException('Invalid key ' + methodKey);
    }

    public sObject createAccount(Map<String, Object> fieldVals, Boolean doDml) {
        Integer i = getNext('Account');
        fieldVals.put('i', i);
        Account a = new Account(Name = 'Test Account ' + i);
        return finish(a, fieldVals, doDml);
    }

    public sObject createOpportunity(
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        Integer i = getNext('Opportunity');
        fieldVals.put('i', i);
        Opportunity o = new Opportunity(
            Name = 'Test Opp ' + i,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        return finish(o, fieldVals, doDml);
    }
}
