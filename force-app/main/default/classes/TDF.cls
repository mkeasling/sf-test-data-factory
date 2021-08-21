@isTest
public with sharing class TDF {
    // filter the given map to only the subset of keys provided
    public static Map<String, Object> filterKeys(
        Map<String, Object> orig,
        Set<String> keys
    ) {
        Map<String, Object> result = new Map<String, Object>();
        for (String key : orig.keySet()) {
            if (keys.contains(key)) {
                result.put(key, orig.get(key));
            }
        }
        return result;
    }

    public static Map<String, Integer> counters;
    public static Integer getNext(String sObjectName) {
        if (counters == null)
            counters = new Map<String, Integer>();
        sObjectName = sObjectName.toLowerCase().trim();
        Integer i = counters.get(sObjectName);
        if (i == null)
            i = 0;
        counters.put(sObjectName, (++i));
        return i;
    }

    public static sObject assignFieldVals(
        sObject obj,
        Map<String, Object> fieldVals
    ) {
        if (fieldVals != null && !fieldVals.isEmpty()) {
            for (String key : fieldVals.keySet()) {
                if (key.equalsIgnoreCase('RecordType'))
                    continue;
                if (key.equalsIgnoreCase('RecordTypeName'))
                    continue;
                if (key.equalsIgnoreCase('RecordTypeDevName'))
                    continue;
                if (key.equalsIgnoreCase('ProfileName'))
                    continue;
                if (key.equalsIgnoreCase('Profile'))
                    continue;
                if (key.equalsIgnoreCase('i'))
                    continue;
                // give the ability to use placeholders, eg. 'Description {{i}}'
                try {
                    String sVal = (String) fieldVals.get(key);
                    String sRes = '';
                    List<String> pieces = sVal.split('(\\{\\{|\\}\\})');
                    for (Integer i = 0; i < pieces.size(); i++) {
                        if (Math.mod(i, 2) == 0) {
                            sRes += pieces[i];
                        } else {
                            try {
                                String v = String.valueOf(
                                    fieldVals.get(pieces[i])
                                );
                                if (v != null) {
                                    sRes += v;
                                } else {
                                    sRes += '{{' + pieces[i] + '}}';
                                }
                            } catch (TypeException e) {
                            }
                        }
                    }
                    obj.put(key, sRes);
                } catch (Exception e) {
                    try {
                        obj.put(key, fieldVals.get(key));
                    } catch (SObjectException se) {
                    }
                }
            }
        }
        return obj;
    }

    public static Boolean doDml(sObject obj, Boolean doDml) {
        if (doDml == false)
            return false;
        insert obj;
        return true;
    }

    public static Boolean doDml(List<sObject> objs, Boolean doDml) {
        if (doDml == false)
            return false;
        insert objs;
        return true;
    }

    public static sObject finishWithRt(
        sObject obj,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        return finishWithRt(obj, fieldVals, null, doDml);
    }
    public static sObject finishWithRt(
        sObject obj,
        Map<String, Object> fieldVals,
        String defaultRecordTypeName,
        Boolean doDml
    ) {
        obj = populateRecordTypeId(obj, fieldVals, defaultRecordTypeName);
        return finish(obj, fieldVals, doDml);
    }
    public static sObject finish(
        sObject obj,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        obj = assignFieldVals(obj, fieldVals);
        doDml(obj, doDml);
        return obj;
    }

    public static String getName(
        String sObjectName,
        Map<String, Object> fieldVals
    ) {
        return getName(sObjectName, fieldVals, 'Name');
    }
    public static String getName(
        String sObjectName,
        Map<String, Object> fieldVals,
        String nameField
    ) {
        if (fieldVals != null && fieldVals.containsKey(nameField)) {
            return (String) fieldVals.get(nameField);
        } else {
            Integer i = getNext(sObjectName);
            return 'Test ' +
                sObjectName.replaceAll('__c', '').replaceAll('_', ' ') +
                ' ' +
                i;
        }
    }

    public static sObject populateRecordTypeId(
        sObject obj,
        Map<String, Object> fieldVals
    ) {
        return populateRecordTypeId(obj, fieldVals, null);
    }
    public static sObject populateRecordTypeId(
        sObject obj,
        Map<String, Object> fieldVals,
        String defaultRecordTypeName
    ) {
        if (fieldVals == null)
            return obj;
        if (obj == null)
            return obj;

        String rtName = (String) fieldVals.get('RecordType');
        if (rtName == null)
            rtName = (String) fieldVals.get('RecordTypeName');
        if (rtName == null)
            rtName = (String) fieldVals.get('RecordTypeDevName');
        if (rtName == null)
            rtName = defaultRecordTypeName;
        if (rtName == null)
            return obj;

        Schema.DescribeSObjectResult objDesc = obj.getSObjectType()
            .getDescribe();
        Map<String, Schema.RecordTypeInfo> rtsByDevName = objDesc.getRecordTypeInfosByDeveloperName();
        Map<String, Schema.RecordTypeInfo> rtsByName = objDesc.getRecordTypeInfosByName();

        Schema.RecordTypeInfo rti = rtsByDevName.get(rtName);
        if (rti == null)
            rti = rtsByName.get(rtName);
        if (rti == null)
            return obj;

        obj.put('RecordTypeId', rti.getRecordTypeId());
        return obj;
    }

    public static List<ApexClass> tdfClasses {
        get {
            if (tdfClasses == null) {
                tdfClasses = [
                    SELECT Id, Name
                    FROM ApexClass
                    WHERE Name LIKE 'TDF_%'
                ];
            }
            return tdfClasses;
        }
        set;
    }

    public static List<Provider> tdfProviders;

    static {
        tdfProviders = new List<Provider>();
        for (ApexClass a : tdfClasses) {
            if (!a.Name.startsWith('TDF_'))
                continue;
            Provider p = (Provider) Type.forName(a.Name).newInstance();
            tdfProviders.add(p);
        }
    }

    public static Map<String, Provider> tdfProvidersByMethod {
        get {
            if (tdfProvidersByMethod == null) {
                tdfProvidersByMethod = new Map<String, Provider>();
            }
            return tdfProvidersByMethod;
        }
        set;
    }

    public static void registerMethod(String methodKey, Provider instance) {
        if (tdfProvidersByMethod.containsKey(methodKey)) {
            throw new TestDataException(
                'Duplicate methodKey [' +
                methodKey +
                '] detected.'
            );
        }
        tdfProvidersByMethod.put(methodKey, instance);
    }

    public static SObject call(
        String methodKey,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        if (fieldVals == null)
            fieldVals = new Map<String, Object>();
        Provider p = tdfProvidersByMethod.get(methodKey);
        if (p == null) {
            for (Provider pro : tdfProviders) {
                try {
                    Sobject result = pro.call(methodKey, fieldVals, doDml);
                    registerMethod(methodKey, pro);
                    return result;
                } catch (MissingMethodException e) {
                    continue;
                }
            }
            throw new TestDataException(
                'Could not find a provider for methodKey ' + methodKey
            );
        }
        return p.call(methodKey, fieldVals, doDml);
    }

    public static List<SObject> callMany(
        String methodKey,
        List<Map<String, Object>> fieldValList,
        Boolean doDml
    ) {
        List<SObject> result = new List<SObject>();
        for (Map<String, Object> fieldVals : fieldValList) {
            result.add(call(methodKey, fieldVals, false));
        }
        if (doDml) {
            insert result;
        }
        return result;
    }

    public static List<SObject> callMany(
        String methodKey,
        Integer times,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        List<Map<String, Object>> fieldValList = new List<Map<String, Object>>();
        for (Integer i = 0; i < times; i++) {
            if (fieldVals == null) {
                fieldValList.add(null);
                continue;
            }
            Map<String, Object> fvs = new Map<String, Object>();
            for (String key : fieldVals.keySet()) {
                Object ov = fieldVals.get(key);
                List<Object> lv;
                try {
                    lv = (List<Object>) ov;
                } catch (Exception e) {
                }
                if (lv != null) {
                    if (lv.size() != times)
                        throw new TestDataException(
                            'The list of values for key ' +
                            key +
                            ' must match the size ' +
                            times
                        );
                    ov = lv[i];
                }
                fvs.put(key, ov);
            }
            fieldValList.add(fvs);
        }
        return callMany(methodKey, fieldValList, doDml);
    }

    public abstract class Provider {
        /**
         * This method takes a key, a fieldVals object, and doDml param.
         * It is responsible for calling the appropriate method and passing along the variables.
         */
        public abstract SObject call(
            String methodKey,
            Map<String, Object> fieldVals,
            Boolean doDml
        );
        // {
        //     switch on methodKey {
        //         when 'createObject1' {
        //             createObject1(fieldVals, doDml);
        //         }
        //         when 'createObject2' {
        //             createObject2(fieldVals, doDml);
        //         }
        //     }
        // }

        public virtual Map<String, Object> filterKeys(
            Map<String, Object> orig,
            Set<String> keys
        ) {
            return TDF.filterKeys(orig, keys);
        }
        public virtual Integer getNext(String sObjectName) {
            return TDF.getNext(sObjectName);
        }
        public virtual sObject assignFieldVals(
            sObject obj,
            Map<String, Object> fieldVals
        ) {
            return TDF.assignFieldVals(obj, fieldVals);
        }
        public virtual Boolean doDml(sObject obj, Boolean doDml) {
            return TDF.doDml(obj, doDml);
        }
        public virtual Boolean doDml(List<sObject> objs, Boolean doDml) {
            return TDF.doDml(objs, doDml);
        }
        public virtual sObject finishWithRt(
            sObject obj,
            Map<String, Object> fieldVals,
            Boolean doDml
        ) {
            return TDF.finishWithRt(obj, fieldVals, doDml);
        }
        public virtual sObject finishWithRt(
            sObject obj,
            Map<String, Object> fieldVals,
            String defaultRecordTypeName,
            Boolean doDml
        ) {
            return TDF.finishWithRt(
                obj,
                fieldVals,
                defaultRecordTypeName,
                doDml
            );
        }
        public virtual sObject finish(
            sObject obj,
            Map<String, Object> fieldVals,
            Boolean doDml
        ) {
            return TDF.finish(obj, fieldVals, doDml);
        }
        public virtual String getName(
            String sObjectName,
            Map<String, Object> fieldVals
        ) {
            return TDF.getName(sObjectName, fieldVals);
        }
        public virtual String getName(
            String sObjectName,
            Map<String, Object> fieldVals,
            String nameField
        ) {
            return TDF.getName(sObjectName, fieldVals, nameField);
        }
        public virtual sObject populateRecordTypeId(
            sObject obj,
            Map<String, Object> fieldVals
        ) {
            return TDF.populateRecordTypeId(obj, fieldVals);
        }
        public virtual sObject populateRecordTypeId(
            sObject obj,
            Map<String, Object> fieldVals,
            String defaultRecordTypeName
        ) {
            return TDF.populateRecordTypeId(
                obj,
                fieldVals,
                defaultRecordTypeName
            );
        }
    }

    public class TestDataException extends Exception {
    }
    public class MissingMethodException extends Exception {
    }
}
