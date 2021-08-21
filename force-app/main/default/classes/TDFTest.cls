@IsTest
public with sharing class TDFTest {
    // Test creating a user and assigning a permset.
    // These funcitons are provided by the TDF_User class.
    private static testMethod void testCreateUser() {
        Test.startTest();
        User u = (User) TDF.call('createUser', null, true);
        PermissionSetAssignment psa = (PermissionSetAssignment) TDF.call(
            'assignPermsetToUser',
            new Map<String, Object>{
                'permsetName' => 'SalesUserPsl',
                'userId' => u.Id
            },
            null
        );

        System.assertNotEquals(null, psa.Id);
        System.assertEquals(u.Id, psa.AssigneeId);
        Test.stopTest();
    }

    // Test creating bulk accounts and related opportunities.
    // These funcitons are provided by the TDF_SalesObjects class.
    private static testMethod void testCreateAcctsAndOpps() {
        Integer times = 10;
        Test.startTest();
        List<Account> accts = (List<Account>) TDF.callMany(
            'createAccount',
            times,
            new Map<String, Object>{
                'Description' => 'Description {{j}} {{i}}'
            },
            true
        );
        List<Opportunity> opps = (List<Opportunity>) TDF.callMany(
            'createOpportunity',
            times,
            new Map<String, Object>{
                'AccountId' => new List<Id>(
                    new Map<Id, Account>(accts).keySet()
                ),
                'Description' => 'Description {{i}}'
            },
            true
        );
        List<Opportunity> result = [
            SELECT
                Id,
                Name,
                Description,
                AccountId,
                Account.Name,
                Account.Description
            FROM Opportunity
        ];
        System.assertEquals(times, result.size());
        System.assertEquals('Test Opp 1', result[0].Name);
        System.assertEquals('Test Account 1', result[0].Account.Name);
        System.assertEquals(
            'Description {{j}} 1',
            result[0].Account.Description
        );
        System.assertEquals('Description 1', result[0].Description);
    }
}
