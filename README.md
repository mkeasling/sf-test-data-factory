# Test Data Factory

## Introduction

The TestDataFactory is a common pattern in which a single class (or, in this case, group of classes) is used by most/all unit tests, to perform the creation of test data during unit test execution.  The reason for this is that it makes it much easier to maintain unit tests over time.  For example, let's imagine that you are NOT using a single TestDataFactory, but are, instead, creating all test data directly inside your unit tests.  If you have 30 unit tests that all create Accounts, then you'll have 30 places in code that look something like this:

```
Account a = new Account(Name = 'Test Account');
insert a;
```

While that doesn't seem to bad at first, let's imagine, now, that we need to add a new required field to the Account record.  Now, we have to go into 30 separate unit tests and modify the above code 30 times.

Now, let's imagine that same scenario with a TestDataFactory in place.  Instead of having to update 30 unit tests, you will have a single place in code that is responsible for creating all Accounts, and so you'll only need to update that one place.  All 30 unit tests that use the TestDataFactory will automatically start creating their accounts with the new required field.

Ahh.  That's better.

## Approach

This TestDataFactory implementation is a slight variation on that usual pattern.  While the normal TestDataFactory pattern relies on a single class with lots of creation method in it, this implementation supplies a single entry point to all TestData classes, while putting the individual creation methods into smaller, logically-grouped classes.  For example, you can have 1 class deal with Users -- creating test users, assigning permission sets, etc., another for Sales Objects (Accounts, Opportunities, etc.), and more, over time, for whatever other custom objects you might need.  The benefits of this approach are several:

1. It separates out the "plumbing" logic -- all the stuff needed to support the TestData creation methods -- from the actual creation logic, making it much easier to find the logic you care about
2. It makes it much easier to share code -- the basic TestDataFactory can be re-used freely, without needing to edit out details of your specific test creation logic.
3. It makes it simpler to group things logically.  No more searching through one monolithic file to find your function!  This also has the side effect of reducing the frequency of merge conflicts!

## How it Works

The TDF class serves as the entry point for all factory methods.  Instead of calling your creation methods directly, you'll pass everything through a `call()` or `callMany()` function.  The `call*()` methods in the `TDF` class will take care of locating and invoking the appropriate creation method.

## Defining Test Data Creation classes & methods

In order to enable dynamic method invocation, we must use a form of the Callable pattern.  Namely, we must define a `call()` method on each class, which handles finding and invoking the appropriate method.  It looks like this:

```apex
@IsTest
public with sharing class TDF_MyProvider extends TDF.Provider {
    public override sObject call(
        String methodKey,
        Map<String, Object> fieldVals,
        Boolean doDml
    ) {
        switch on methodKey {
            when 'createAccount' {
                return createAccount(fieldVals, doDml);
            }
            when 'methodOne' {
                return methodOne(fieldVals, doDml);
            }
            when 'methodTwo' {
                return methodTwo(fieldVals, doDml);
            }
        }
        throw new MissingMethodException('Invalid key ' + methodKey);
    }

    public sObject createAccount(Map<String, Object> fieldVals, Boolean doDml) {
        Integer i = getNext('Account');
        fieldVals.put('i', i);
        Account a = new Account(
            Name = 'Test Account ' + i,
            Required_Field__c = 'req-value'
        );
        return finish(a, fieldVals, doDml);
    }

    public sObject methodOne(Map<String, Object> fieldVals, Boolean doDml) {
        // your logic
    }

    public sObject methodTwo(Map<String, Object> fieldVals, Boolean doDml) {
        // your logic
    }
}
```

Notice the `call()` method must take 3 parameters:
1. `String methodKey`.  This is public-facing name of the method you want to expose.
2. `Map<String, Object> fieldVals`.  This is a key-value map of different values you want to populate on the object being created.  Your creation method is responsible for providing reasonable defaults for all required fields, and this parameter allows calling code to provide additional (or replacement!) values, as desired, for any other fields on the object.
3. `Boolean doDml`.  This determines whether the generated object should actually be inserted into the database or not.  When creating multiple records at once, it is usually desirable to NOT actually perform the DML until you can insert all objects at the same time.

The call simply uses the `methodKey` value to determine which method to run, and then calls it directly, passing along the values.

If we take a closer look at the example `createAccount()` method, we'll notice that it's doing several things:
- It's using a built-in counter to get a unique integer for the Account object.  This allows us to create multiple Account records in a single transaction, and number them based on creation order.  This is super useful for objects that have *Unique* constraints, as this helps us give each object a unique value.
- It's adding the counter value to `fieldVals`, as a new parameter, `i`.  By adding it to `fieldVals`, it enables us to re-use this value later on -- specifically by utilizing string replacement.  We'll get to that later.
- It's creating an Account object that satisfies all the requirements for a successful record insertion.  It's important that this method be responsible for meeting all basic requirements.  If there are required fields that *cannot* be defaulted (for example, a required relationship field, that needs another record to be created first), then it's important that this method enforce those requirements by checking the `fieldVals` and throwing an exception when needed.
- It's calling the `finish()` method, and passing along the record it created, as well as `fieldVals` and `doDml`.  The `finish()` method will be responsible for the remaining logic -- it populates the object with any applicable `fieldVals` and, if specified, performs the actual DML insert.

## Using the TestDataFactory methods

We've just seen how to build the creation classes & methods.  Now, let's see how to utilize them in our tests.

### Single-record creation

The most common form of calling these functions is to create one record at a time.  Here's what that looks like:

```
private static testMethod void myTest() {
    Account a = (Account) TDF.call('createAccount', new Map<String, Object>{
        'Description' => 'My Description {{i}}'
    }, true);
}
```

In this example, we're calling the `createAccount()` method, passing in a `fieldVals` that specifies a `Description` value, and a `doDml` value of `true`.  This will result in an Account record being written to the database, that looks like this (assuming that this is the first Account record we've created in our test):

```
{
    Id: '001XXXXXXXXXXXX001',
    Name: 'Test Account 1',
    Description: 'My Description 1',
    Required_Field__c: 'req-value'
}
```

Notice that the string `{{i}}` got replaced with the value ``i`` that we defined in the `createAccount()` method.  Any values that are defined in the `fieldVals` object can be inserted into any string values in this same way.  While it is a recommendation to consistenly use the key `i` for your incrementor, this is just a convention -- you are responsible for implementing that logic in your own creation methods, and for understanding how those methods work when using them.

### Multi-record creation

In addition to the `call()` function just demonstrated, there are also 2 forms of the `callMany()` function.  These ultimately end up making repeated invocations of the `call()` method, and as such, operate in a very similar way.  However, they never perform DML until all specified records have been created (and then, only if `doDml` is set to *true*).

**List of `fieldVals`**

The first form of `callMany()` takes the same parameters as `call()`, *except that* it takes a `List<Map<String, Object>> fieldValList` instead of a single `Map<String, Object> fieldVals`.  In this form, the `callMany()` function will cycle through the List of fieldVals, and invoke the `call()` method one time for each item in the list.

**Count of times to run**

The second form of `callMany()` adds a new parameter, `Integer times`, and has a *single* `Map<String, Object> fieldVals` value.  This causes the `call()` method to be invoked the specified number of `times`, and the same `fieldVals` object to be passed on each invocation (for the most part).  Thus, if you were to call `TDF.callMany('createAccount', 10, null, true);`, you would end up with 10 identical Account objects, with the only difference being the incrementor values in the `Account.Name` field.

The exception to this is that you have the *option* of passing a `List<Object>` inside any of the `fieldVals` values.  **When you do this, the number of items in the `List` MUST match the value you gvae for `times`!**  When `callMany()` detects a `List` as one of the values, then it will provide unique `fieldVals` parameters for each invocation of `call()`.  Any non-List values will be identical for each invocation, but any List values will be unique for each invocation.  For example:

```
Integer times = 10;
List<Account> accts = (List<Account>) TDF.callMany('createAccount', times, null, true);

List<Opportunity> opps = (List<Opportunity>) TDF.callMany('createOpportunity', times, new Map<String, Object>{
    'AccountId' => new List<Id>(new Map<Id, Account>(accts).keySet()),
    'Description' => 'Description {{i}}'
}, true);
```

In this example, we first create 10 Account records.  We pass `null` for `fieldVals`, meaning that we are NOT customizing these accounts in any way -- the `createAccount()` method is 100% responsible for setting these up correctly.

Next, we create 10 Opportunity records.  We pass a `fieldVals` with 2 fields defined:
- `AccountId` gets a `List<Id>`, which is populated with the 10 Account IDs that we just created.  NOTE: It's imperative that this `List` has exactly 10 entries, as we've specified that we're calling `createAccount` 10 times.
- `Description` gets a single String.  Because this is not a `List`, but rather just a single value, the same exact string will be passed to `createAccount` on every invocation.  (Because the string has a placeholder in it, the end value will still be different for each record!  But, without the placeholder, every record would end up with an identical string in the `Description` field).

## Record Types

When working on objects with Record Types, you will often need to supply Record Type IDs as part of your test data creation.  In order to simplify this process, the TDF class has Record Type support built-in!  When writing a test data creation method for an object that uses record types, you need only change one line of your method!  It looks like this:

```
public sObject createAccount(Map<String, Object> fieldVals, Boolean doDml) {
        Integer i = getNext('Account');
        fieldVals.put('i', i);
        Account a = new Account(
            Name = 'Test Account ' + i,
            Required_Field__c = 'req-value'
        );
        return finishWithRt(a, fieldVals, 'DefaultRecordType', doDml); // all that you need to modify!
}
```

On the last line, instead of calling `finish()`, you'll call `finishWithRt()` instead, and you'll provide the default Record Type Name as an additional option (after `fieldVals` and before `doDml`).  Note, you don't need to find the Record Type Id -- that's all handled for you automatically.  And indeeed, any calling code can take advantage of the same feature!  To *use* a record-type-enabled creation method, you invoke `call()` in exactly the same way as any other method.  The only difference is that you can *optionally* provide `RecordTypeName` as one of the `fieldVals` parameters.  That will cause the *default* record type value to be overridden with whatever you provide.  No Id lookups necessary!

## Conclusion

The Test Data Factory pattern is a common and powerful pattern in Salesforce development.  This implementation seeks to make it very simple to build and organize new methods for creating different types of test data.  It also attempts to make it very easy and consistent to use these methods throughout your test code.  By adopting this framework, you will gain the ability to quickly and easily create all sorts of test data, with a robust set of defaults, and the ability to easily override those defaults to create whatever specific records you need for your tests.