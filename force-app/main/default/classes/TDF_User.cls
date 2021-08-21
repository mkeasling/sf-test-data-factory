@IsTest
public with sharing class TDF_User extends TDF.Provider {
    // This method must return a complete list of 
    public override Set<String> getMethodKeys() {
        return new Set<String>{ 
            'assignPermsetToUser', 
            'createUser' 
        };
    }

    public override SObject call(
        String methodKey,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        switch on methodKey {
            when 'assignPermsetToUser' {
                return assignPermsetToUser(fieldVals, doDml);
            }
            when 'createUser' {
                return createUser(fieldVals, doDml);
            }
        }
        throw new TestDataException('Could not find appropriate method.');
    }

    public static Map<String, Id> profilesByName {
        get {
            if (profilesByName == null) {
                profilesByName = new Map<String, Id>();
                for (Profile p : [SELECT Id, Name FROM Profile]) {
                    profilesByName.put(p.Name, p.Id);
                }
            }
            return profilesByName;
        }
        private set;
    }

    public static Map<String, Id> permsetsByName {
        get {
            if (permsetsByName == null) {
                permsetsByName = new Map<String, Id>();
                for (PermissionSet p : [SELECT Id, Name FROM PermissionSet]) {
                    permsetsByName.put(p.Name, p.Id);
                }
            }
            return permsetsByName;
        }
        private set;
    }

    public User createUser(Map<String, Object> fieldVals, Boolean doDml) {
        Integer i = getNext('User');
        String profileName = 'System Administrator';
        Id profileId;
        if (fieldVals != null) {
            if (fieldVals.containsKey('ProfileId')) {
                profileId = (Id) fieldVals.get('ProfileId');
            } else if (fieldVals.containsKey('ProfileName')) {
                profileName = (String) fieldVals.get('ProfileName');
            } else if (fieldVals.containsKey('Profile')) {
                profileName = (String) fieldVals.get('ProfileName');
            }
        }
        if (profileId == null) {
            profileId = profilesByName.get(profileName);
        }
        User u = new User(
            Alias = 'test' + i,
            Email = 'test.user.' + i + '@maildrop.cc',
            FirstName = 'Test' + i,
            LastName = 'User' + i,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'test.user.' + i + '@maildrop.cc',
            ProfileId = profileId
        );
        return (User) finish(u, fieldVals, doDml);
    }

    public static PermissionSetAssignment assignPermsetToUser(
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        if (
            fieldVals == null ||
            String.isBlank((String) fieldVals.get('permsetName')) ||
            String.isBlank((String) fieldVals.get('userId'))
        ) {
            throw new TestDataException(
                'You must provide a permsetName and a userId'
            );
        }
        if (doDml == false) {
            throw new TestDataException(
                'The assignPermsetToUser function requires DML.  Please provide TRUE or NULL.'
            );
        }
        String permsetName = (String) fieldVals.get('permsetName');
        Id userId = (Id) fieldVals.get('userId');
        Id permsetId = permsetsByName.get(permsetName);
        if (permsetId == null)
            throw new TestDataException(
                'Could not find Permission Set with name: ' + permsetName
            );
        PermissionSetAssignment psa = new PermissionSetAssignment(
            PermissionSetId = permsetId,
            AssigneeId = userId
        );
        insert psa;
        return psa;
    }
}
