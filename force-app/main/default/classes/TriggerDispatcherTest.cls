/**
 * Created by sonal on 2025-01-12.
 */

@IsTest
public class TriggerDispatcherTest {
    @IsTest
    static void testAccountContactCreation() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.AccountUpdateAnnualRevenue',
                IsActive__c = true,
                LoadOrder__c = 10,
                BeforeInsert__c = true,
                BeforeUpdate__c = true
            )
        );
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestB',
                Handler__c = 'TriggerDispatcherTest.ContactCreateHandler',
                IsActive__c = true,
                LoadOrder__c = 20,
                AfterInsert__c = true,
                AfterUpdate__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', mocks);

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );

        Test.startTest();
        insert newAccount;

        List<Contact> contacts = [SELECT Id, Account.AnnualRevenue FROM Contact WHERE AccountId = :newAccount.Id];
        System.assertEquals(1, contacts.size());
        System.assertEquals(100000, contacts[0].Account.AnnualRevenue);

        newAccount.AnnualRevenue = 0;
        update newAccount;
        Test.stopTest();

        contacts = [SELECT Id, Account.AnnualRevenue FROM Contact WHERE AccountId = :newAccount.Id];
        System.assertEquals(2, contacts.size());
        System.assertEquals(200000, contacts[0].Account.AnnualRevenue);
    }

    @IsTest
    static void testAsyncMode() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.ContactCreateHandlerAsync',
                IsActive__c = true,
                LoadOrder__c = 20,
                AfterInsert__c = true,
                Asynchronous__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', mocks);
        TriggerDispatcher.forceQueueableDefer = false;

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );
        Test.startTest();
        insert newAccount;
        Test.stopTest();

        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :newAccount.Id];
        System.assertEquals(1, contacts.size());
    }

    @IsTest
    static void testDeferAsyncMode() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
                new TriggerFeature__mdt(
                        DeveloperName = 'TriggerDispatcherTestA',
                        Handler__c = 'TriggerDispatcherTest.ContactCreateHandlerAsync',
                        IsActive__c = true,
                        LoadOrder__c = 20,
                        AfterInsert__c = true,
                        Asynchronous__c = true
                )
        );
        TriggerDispatcher.setMockControls('Account', mocks);
        TriggerDispatcher.forceQueueableDefer = true;
        DeferredJobProcessor.isScheduleOverride = true;

        Account newAccount = new Account(
                Name = 'New Test Account',
                Industry = 'Finance',
                BillingCountry = 'Canada',
                BillingState = 'Ontario',
                AnnualRevenue = 0
        );
        Test.startTest();
        insert newAccount;

        List<DeferredQueueableJob__c> deferredQueueableJobs = [SELECT Id FROM DeferredQueueableJob__c];
        System.assertEquals(1, deferredQueueableJobs.size());

        new DeferredJobProcessor().execute(null);

        Test.stopTest();

        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :newAccount.Id];
        System.assertEquals(1, contacts.size());
    }

    @IsTest
    static void testAsyncModeBefore() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.ContactCreateHandlerAsync',
                IsActive__c = true,
                LoadOrder__c = 20,
                BeforeInsert__c = true,
                Asynchronous__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', mocks);

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );
        Boolean exceptionFound = false;
        try {
            insert newAccount;
        } catch (Exception e) {
            exceptionFound = true;
        }

        System.assertEquals(true, exceptionFound);
    }

    @IsTest
    static void testTriggerMetrics() {
        List<TriggerFeature__mdt> accountMocks = new List<TriggerFeature__mdt>();

        accountMocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.ContactCreateHandler',
                IsActive__c = true,
                LoadOrder__c = 20,
                AfterInsert__c = true,
                AfterUpdate__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', accountMocks);
        TriggerMetrics.isMetricsEnabled = true;

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );

        Test.startTest();
        insert newAccount;

        Test.stopTest();

        List<Contact> contacts = [SELECT Id, FirstName FROM Contact WHERE AccountId = :newAccount.Id];
        System.assertEquals(1, contacts.size());
    }

    @IsTest
    static void testNonExistentClass() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.NonExistentClass',
                IsActive__c = true,
                LoadOrder__c = 10,
                BeforeInsert__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', mocks);

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );

        Boolean exceptionFound = false;
        try {
            insert newAccount;
        } catch (Exception e) {
            exceptionFound = true;
        }

        System.assertEquals(true, exceptionFound);
    }

    @IsTest
    static void testInvalidClass() {
        List<TriggerFeature__mdt> mocks = new List<TriggerFeature__mdt>();
        mocks.add(
            new TriggerFeature__mdt(
                DeveloperName = 'TriggerDispatcherTestA',
                Handler__c = 'TriggerDispatcherTest.InvalidClass',
                IsActive__c = true,
                LoadOrder__c = 10,
                BeforeInsert__c = true
            )
        );
        TriggerDispatcher.setMockControls('Account', mocks);

        Account newAccount = new Account(
            Name = 'New Test Account',
            Industry = 'Finance',
            BillingCountry = 'Canada',
            BillingState = 'Ontario',
            AnnualRevenue = 0
        );

        Boolean exceptionFound = false;
        try {
            insert newAccount;
        } catch (Exception e) {
            exceptionFound = true;
        }

        System.assertEquals(true, exceptionFound);
    }

    public class AccountUpdateAnnualRevenue implements ITriggerExecutable {
        public void execute(TriggerContext context) {
            for (Account acc : (List<Account>) context.getRecords()) {
                if (context.beforeInsert()) {
                    acc.AnnualRevenue += 100000;
                } else if (context.beforeUpdate() && context.isChanged(acc, Account.AnnualRevenue)) {
                    acc.AnnualRevenue += 200000;
                }
            }
        }
    }

    public class ContactCreateHandler implements ITriggerExecutable {
        public void execute(TriggerContext context) {
            List<Contact> contacts = new List<Contact>();
            for (Account acc : (List<Account>) context.getRecords()) {
                contacts.add(new Contact(LastName = acc.Name, AccountId = acc.Id));
            }
            insert contacts;
        }
    }

    public class ContactCreateHandlerAsync implements ITriggerExecutable {
        public void execute(TriggerContext context) {
            List<Contact> contacts = new List<Contact>();
            for (Id accountId : (Set<Id>) context.getRecordIds()) {
                contacts.add(new Contact(LastName = 'Demo', AccountId = accountId));
            }
            insert contacts;
        }
    }

    public class InvalidClass {
        public void execute(TriggerContext context) {
            Integer i = 1;
        }
    }
}
