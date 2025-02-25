# Salesforce Apex Trigger Framework Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Framework Overview](#framework-overview)
3. [Key Components](#key-components)
4. [Implementation Guide](#implementation-guide)
   - [Step 1: Implement Trigger](#step-1-implement-trigger)
   - [Step 2: Implement ITriggerExecutable](#step-2-implement-itriggerexecutable)
   - [Step 3: Configure Trigger Features](#step-3-configure-trigger-features)
5. [Advanced Features](#advanced-features)
   - [Asynchronous Execution](#asynchronous-execution)
   - [Deferred Job Processing](#deferred-job-processing)
   - [Bypass and Required Permissions](#bypass-and-required-permissions)
   - [Performance Metrics](#performance-metrics)
   - [Disabling Triggers](#disabling-triggers)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Examples](#examples)
   - [Basic Usage](#basic-usage)
   - [Multiple Handlers](#multiple-handlers)
   - [Asynchronous Handler](#asynchronous-handler)
   - [Working with Context Methods](#working-with-context-methods)
   - [Nested Handler Classes](#nested-handler-classes)

## Introduction

This document provides comprehensive documentation for a custom Salesforce Apex trigger framework. The framework is designed to simplify trigger management, improve code organization, and enhance maintainability of Salesforce applications. It offers a flexible and scalable approach to handling complex trigger logic across multiple objects with built-in support for asynchronous processing.

## Framework Overview

The framework is built on the following key principles:

1. **Separation of Concerns**: Trigger logic is separated from the trigger itself, allowing for better organization and reusability.
2. **Configurability**: Trigger behavior is controlled through custom metadata, enabling easy management without code changes.
3. **Extensibility**: The framework supports multiple handlers per object and trigger event, allowing for modular and scalable trigger logic.
4. **Performance Monitoring**: Built-in metrics tracking helps identify and optimize performance bottlenecks.
5. **Asynchronous Execution**: Support for asynchronous trigger execution to handle complex or long-running operations.
6. **Deferred Processing**: Ability to queue jobs for later execution when Queueable limits are reached.

## Key Components

The framework consists of several components that work together:

- **Trigger Handler Interface**: Defines the contract for all trigger handlers
- **Trigger Context**: Encapsulates all trigger execution information
- **Trigger Dispatcher**: Central component that manages trigger execution
- **Custom Metadata**: Configures which handlers run for each object and event
- **Performance Metrics**: Tracks execution times and resource usage
- **Deferred Processing**: Handles jobs that exceed governor limits

## Implementation Guide

### Step 1: Implement Trigger

Create a trigger for your object that calls the `TriggerDispatcher`:

```apex
trigger AccountTrigger on Account (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    TriggerDispatcher.run(Account.SObjectType);
}
```

This simple trigger delegates all processing to the framework. There's no need to write any logic directly in the trigger file.

### Step 2: Implement ITriggerExecutable

Create a class that implements the `ITriggerExecutable` interface for each piece of trigger logic you want to execute:

```apex
public class AccountTriggerHandler implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.beforeInsert()) {
            handleBeforeInsert(context);
        } else if (context.afterUpdate()) {
            handleAfterUpdate(context);
        }
    }
    
    private void handleBeforeInsert(TriggerContext context) {
        List<SObject> records = context.getRecords();
        for (SObject record : records) {
            Account acc = (Account)record;
            // Handle before insert logic
        }
    }
    
    private void handleAfterUpdate(TriggerContext context) {
        // In synchronous mode
        if (!context.isAsyncMode) {
            List<SObject> records = context.getRecords();
            // Process records
        } 
        // In asynchronous mode
        else {
            Set<Id> recordIds = context.getRecordIds();
            // Process record IDs
        }
    }
}
```

The `TriggerContext` object provides helpful methods to:
- Determine the current trigger operation (`beforeInsert()`, `afterUpdate()`, etc.)
- Access records being processed (`getRecords()`)
- Check if fields have changed (`isChanged()`)

### Step 3: Configure Trigger Features

Create `TriggerFeature__mdt` records for each trigger handler:

1. Go to Setup > Custom Metadata Types
2. Click "Manage Records" next to `TriggerFeature__mdt`
3. Click "New"
4. Fill in the details:
   - Label: A descriptive name (e.g., "Account Before Insert Handler")
   - DeveloperName: A unique API name (e.g., "Account_Before_Insert_Handler")
   - Handler__c: The full name of your handler class (e.g., "AccountTriggerHandler")
   - IsActive__c: Check this to enable the handler
   - LoadOrder__c: Set the execution order (lower numbers execute first)
   - Check appropriate trigger events (BeforeInsert__c, AfterUpdate__c, etc.)
   - SObjectName__c: The API name of the object (e.g., "Account")
   - Asynchronous__c: Check if this should run asynchronously (only for after triggers)
5. Save the record

This metadata-driven approach allows you to:
- Enable/disable handlers without code changes
- Control which trigger events each handler responds to
- Define the order of execution when multiple handlers exist
- Configure asynchronous execution for specific handlers

## Advanced Features

### Asynchronous Execution

To run a handler asynchronously:

1. Set the `Asynchronous__c` field to true in the `TriggerFeature__mdt` record
2. Ensure your handler can work with the limited context provided in async mode

Example:
```apex
public class AsyncAccountHandler implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.isAsyncMode) {
            // In async mode, we can only access record IDs
            Set<Id> accountIds = context.getRecordIds();
            
            // Query for full records if needed
            List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];
            
            // Process accounts
            for (Account acc : accounts) {
                // Perform async processing
            }
        }
    }
}
```

**Important**: Asynchronous execution is not allowed in before triggers. The framework will throw a `TriggerDispatcherException` if attempted.

### Deferred Job Processing

When queueable limits are reached during trigger processing, the framework automatically creates `DeferredQueueableJob__c` records for later processing. This is particularly useful in high-volume scenarios where you might hit the limit of 50 queueable jobs in a transaction.

The deferred job processing feature:
- Automatically creates records for jobs that can't be executed immediately
- Processes these jobs later when queueable slots become available
- Maintains the execution context needed for proper processing

Schedule the processor to run every `n` minutes.

You can customize the processing interval in the `TriggerSettings__c` custom setting.

### Bypass and Required Permissions

You can control trigger execution based on custom permissions:

1. Create custom permissions in Setup
2. Assign them to permission sets
3. Reference them in your trigger features:
   - `BypassPermission__c`: If the user has this permission, the handler will not execute
   - `RequiredPermission__c`: The user must have this permission for the handler to execute

This feature is useful for:
- Allowing administrators to bypass triggers during data loads
- Restricting certain trigger functionality to specific user groups
- Implementing feature toggles based on permissions

### Performance Metrics

The framework includes built-in performance tracking to help identify bottlenecks. Enable this feature in the `TriggerSettings__c` custom setting.

Once enabled, the framework will log detailed metrics to the `TriggerMetric__c` object for each trigger handler execution, including:
- Execution time in milliseconds
- CPU time consumed
- DML rows used
- Query rows used
- Number of records processed

You can use this data to:
- Identify slow-performing trigger handlers
- Monitor resource usage
- Optimize code based on performance metrics
- Track execution patterns over time

### Disabling Triggers

You can disable triggers for specific objects using the `SObjectTriggerControl__c` custom setting.

This completely bypasses all trigger processing for the specified object, which is useful during:
- Data migrations
- Bulk operations
- Testing
- Troubleshooting

## Best Practices

1. Keep handler logic focused and modular
2. Use meaningful names for your handler classes and trigger feature records
3. Set appropriate load orders to ensure correct execution sequence
4. Use asynchronous execution for long-running operations to avoid governor limits
5. Consider the limitations of asynchronous context (limited access to trigger context)
6. Regularly review performance metrics to identify optimization opportunities
7. Use bypass permissions for admin override capabilities
8. Implement unit tests that mock trigger features for better isolation

## Troubleshooting

Common issues and solutions:

1. **Handler not executing**: 
   - Check if the `TriggerFeature__mdt` record is active
   - Verify the `SObjectName__c` field is correct
   - Ensure the appropriate trigger event checkbox is selected

2. **Asynchronous execution not working**: 
   - Confirm the `Asynchronous__c` field is set to true
   - Ensure the handler is not configured for before triggers
   - Check if queueable limits are being reached

3. **Deferred jobs not processing**:
   - Verify the `DeferredJobProcessor` is scheduled
   - Check for errors in the jobs by querying `DeferredQueueableJob__c`
   - Review custom settings for proper configuration

4. **Performance issues**: 
   - Enable metrics and analyze the `TriggerMetric__c` records
   - Look for operations that can be bulkified or optimized

## Examples

### Basic Usage

```apex
public class AccountNameValidator implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.beforeInsert() || context.beforeUpdate()) {
            List<Account> accounts = (List<Account>)context.getRecords();
            for (Account acc : accounts) {
                if (String.isBlank(acc.Name)) {
                    acc.Name.addError('Account name cannot be blank');
                }
            }
        }
    }
}
```

TriggerFeature__mdt record:
- DeveloperName: Account_Name_Validator
- Handler__c: AccountNameValidator
- IsActive__c: True
- LoadOrder__c: 10
- BeforeInsert__c: True
- BeforeUpdate__c: True
- SObjectName__c: Account

### Multiple Handlers

First handler:
```apex
public class AccountIndustryDefaulter implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.beforeInsert()) {
            for (Account acc : (List<Account>)context.getRecords()) {
                if (String.isBlank(acc.Industry)) {
                    acc.Industry = 'Other';
                }
            }
        }
    }
}
```

Second handler:
```apex
public class AccountRelatedContactCreator implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.afterInsert()) {
            List<Contact> newContacts = new List<Contact>();
            for (Account acc : (List<Account>)context.getRecords()) {
                newContacts.add(new Contact(
                    AccountId = acc.Id,
                    LastName = 'Primary Contact'
                ));
            }
            if (!newContacts.isEmpty()) {
                insert newContacts;
            }
        }
    }
}
```

Configure separate TriggerFeature__mdt records for each handler with different load orders.

### Asynchronous Handler

```apex
public class AccountAsyncProcessor implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.afterUpdate()) {
            // In asynchronous mode, we only have access to record IDs
            if (context.isAsyncMode) {
                Set<Id> accountIds = context.getRecordIds();
                
                // Query for the data we need
                List<Account> accounts = [
                    SELECT Id, Name, Industry, BillingCity 
                    FROM Account 
                    WHERE Id IN :accountIds
                ];
                
                // Process accounts asynchronously
                processAccounts(accounts);
            }
            // In synchronous mode, we have full access to trigger context
            else {
                List<Account> accounts = (List<Account>)context.getRecords();
                
                // Check which accounts had industry changes
                List<Account> accountsWithIndustryChanges = new List<Account>();
                for (Account acc : accounts) {
                    if (context.isChanged(acc, Account.Industry)) {
                        accountsWithIndustryChanges.add(acc);
                    }
                }
                
                // Process only accounts with industry changes
                processAccounts(accountsWithIndustryChanges);
            }
        }
    }
    
    private void processAccounts(List<Account> accounts) {
        // Process accounts, possibly making callouts or performing other expensive operations
        for (Account acc : accounts) {
            // Expensive operation here
        }
    }
}
```

TriggerFeature__mdt record:
- DeveloperName: Account_Async_Processor
- Handler__c: AccountAsyncProcessor
- IsActive__c: True
- LoadOrder__c: 20
- AfterUpdate__c: True
- Asynchronous__c: True
- SObjectName__c: Account

### Working with Context Methods

```apex
public class OpportunityProcessor implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        // Using helper methods for operation detection
        if (context.beforeInsert()) {
            handleBeforeInsert(context);
        } else if (context.afterUpdate()) {
            handleAfterUpdate(context);
        }
    }
    
    private void handleBeforeInsert(TriggerContext context) {
        List<Opportunity> opps = (List<Opportunity>)context.getRecords();
        for (Opportunity opp : opps) {
            // Process before insert
        }
    }
    
    private void handleAfterUpdate(TriggerContext context) {
        // Check for field changes
        List<Opportunity> oppsWithChanges = new List<Opportunity>();
        for (Opportunity opp : (List<Opportunity>)context.getRecords()) {
            // Using isChanged method to detect field changes
            if (context.isChanged(opp, Opportunity.StageName) || 
                context.isChanged(opp, Opportunity.Amount)) {
                oppsWithChanges.add(opp);
            }
        }
        
        // Process opportunities with changes
        if (!oppsWithChanges.isEmpty()) {
            // Process changes
        }
    }
}
```

### Nested Handler Classes

You can organize your trigger logic by creating nested handler classes within a main handler class. This approach can help keep related functionality together while still maintaining separation of concerns:

```apex
public with sharing class AccountTriggerHandler implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.isInsert && context.isBefore) {
            // Handle before insert logic
        } else if (context.isUpdate && context.isAfter) {
            // Handle after update logic
        }
        // Add more conditions as needed
    }
    
    public class UpdateDescription implements ITriggerExecutable {
        public void execute(TriggerContext context) {
            for (Account acc : (List<Account>) context.getRecords()) {
                // Update description logic
            }
        }
    }
    
    public class InsertContact implements ITriggerExecutable {
        public void execute(TriggerContext context) {
            // Insert related contact logic
        }
    }
}
```

When configuring these nested handlers in custom metadata, use the full class path:
- For the main handler: `AccountTriggerHandler`
- For nested handlers: `AccountTriggerHandler.UpdateDescription` or `AccountTriggerHandler.InsertContact`

This approach offers several benefits:
- Keeps related functionality organized in a single file
- Reduces the number of separate class files
- Makes it easier to understand the relationship between handlers
- Allows for shared utility methods across handlers

Each nested class can be configured with its own trigger events, load order, and asynchronous settings through separate metadata records.
