# Salesforce Apex Trigger Framework Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Framework Overview](#framework-overview)
3. [Key Components](#key-components)
   - [ITriggerExecutable](#itriggerexecutable)
   - [TriggerContext](#triggercontext)
   - [TriggerDispatcher](#triggerdispatcher)
   - [TriggerFeature__mdt](#triggerfeaturemdt)
   - [DeferredJobProcessor](#deferredjobprocessor)
   - [TriggerMetrics](#triggermetrics)
   - [Custom Settings](#custom-settings)
4. [Implementation Guide](#implementation-guide)
   - [Step 1: Create Custom Metadata Type](#step-1-create-custom-metadata-type)
   - [Step 2: Configure Custom Settings](#step-2-configure-custom-settings)
   - [Step 3: Implement ITriggerExecutable](#step-3-implement-itriggerexecutable)
   - [Step 4: Configure Trigger Features](#step-4-configure-trigger-features)
   - [Step 5: Implement Trigger](#step-5-implement-trigger)
5. [Advanced Features](#advanced-features)
   - [Asynchronous Execution](#asynchronous-execution)
   - [Deferred Job Processing](#deferred-job-processing)
   - [Bypass and Required Permissions](#bypass-and-required-permissions)
   - [Performance Metrics](#performance-metrics)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Examples](#examples)
   - [Basic Usage](#basic-usage)
   - [Multiple Handlers](#multiple-handlers)
   - [Asynchronous Handler](#asynchronous-handler)
   - [Working with Context Methods](#working-with-context-methods)

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

### ITriggerExecutable

The `ITriggerExecutable` interface defines the contract for all trigger handlers. Any class implementing this interface can be used as a trigger handler in the framework.

```apex
public interface ITriggerExecutable {
    void execute(TriggerContext context);
}
```

### TriggerContext

The `TriggerContext` class encapsulates all relevant information about the current trigger execution, including:

- Trigger operation (insert, update, delete, undelete)
- Trigger phase (before, after)
- Old and new record lists and maps
- Helper methods for common trigger operations
- Support for synchronous and asynchronous execution modes

Key methods:
- `getRecords()`: Returns the relevant list of records for the current operation
- `getRecordIds()`: Returns the set of record IDs involved in the operation
- `isChanged(SObject record, Schema.SObjectField field)`: Checks if a specific field has changed
- Helper methods for each trigger context: `beforeInsert()`, `afterUpdate()`, etc.

### TriggerDispatcher

The `TriggerDispatcher` class is the core of the framework. It handles the execution of trigger logic based on the configured trigger features.

Key responsibilities:
- Fetches and caches trigger feature configurations
- Determines which handlers to execute based on the current trigger context
- Manages synchronous and asynchronous execution of handlers
- Creates deferred jobs when queueable limits are reached
- Handles error scenarios and permissions

### TriggerFeature__mdt

This custom metadata type stores the configuration for each trigger feature, including:

- Handler class name
- Enabled trigger events (before insert, after update, etc.)
- Execution order
- Asynchronous execution flag
- Bypass and required permissions

### DeferredJobProcessor

The `DeferredJobProcessor` class processes jobs that were deferred due to queueable limits:

- Implements both `Schedulable` and `Queueable` interfaces
- Processes deferred jobs in batches
- Automatically schedules itself for future execution
- Uses custom settings for configuration

### TriggerMetrics

The `TriggerMetrics` class provides functionality to track and log performance metrics for trigger executions, helping identify potential performance issues:

- Tracks CPU time, DML rows, query rows, and execution time
- Supports buffer-based logging to minimize DML operations
- Configurable via custom settings

### Custom Settings

The framework uses two custom settings:

1. **TriggerSettings__c**:
   - `IsMetricsEnabled__c`: Controls whether performance metrics are collected
   - `MinimumScheduleIntervalMinutes__c`: Controls how frequently the DeferredJobProcessor runs
   - `DeferredJobCronPrefix__c`: Prefix for scheduled job names

2. **SObjectTriggerControl__c**:
   - `SObjectName__c`: API name of the SObject
   - `IsDisabled__c`: Whether triggers are disabled for this SObject

## Implementation Guide

### Step 1: Create Custom Metadata Type

Create a custom metadata type named `TriggerFeature__mdt` with the following fields:

- `DeveloperName` (Text)
- `Handler__c` (Text): Full class name of the handler
- `IsActive__c` (Checkbox): Whether this feature is active
- `LoadOrder__c` (Number): Order of execution (lower numbers execute first)
- `BeforeInsert__c` (Checkbox): Run on before insert
- `AfterInsert__c` (Checkbox): Run on after insert
- `BeforeUpdate__c` (Checkbox): Run on before update
- `AfterUpdate__c` (Checkbox): Run on after update
- `BeforeDelete__c` (Checkbox): Run on before delete
- `AfterDelete__c` (Checkbox): Run on after delete
- `AfterUndelete__c` (Checkbox): Run on after undelete
- `Asynchronous__c` (Checkbox): Run asynchronously (only for after triggers)
- `SObjectName__c` (Text): API name of the object
- `BypassPermission__c` (Text): Custom permission that allows bypassing this trigger
- `RequiredPermission__c` (Text): Custom permission required to run this trigger

### Step 2: Configure Custom Settings

1. Create a custom setting named `TriggerSettings__c` with the following fields:
   - `IsMetricsEnabled__c` (Checkbox): Enable performance metrics
   - `MinimumScheduleIntervalMinutes__c` (Number): Minimum interval for scheduled jobs
   - `DeferredJobCronPrefix__c` (Text): Prefix for scheduled job names

2. Create a custom setting named `SObjectTriggerControl__c` with the following fields:
   - `SObjectName__c` (Text): API name of the SObject
   - `IsDisabled__c` (Checkbox): Whether triggers are disabled for this SObject

3. Create a custom object named `DeferredQueueableJob__c` with the following fields:
   - `HandlerName__c` (Text): Handler class name
   - `ContextData__c` (Long Text Area): Serialized context data
   - `Status__c` (Picklist): Pending, Processed
   - `Operation__c` (Text): Trigger operation
   - `SObjectName__c` (Text): SObject name
   - `LastProcessedDate__c` (DateTime): When the job was last processed

4. Create a custom object named `TriggerMetric__c` with the following fields:
   - `Handler__c` (Text): Handler class name
   - `Operation__c` (Text): Trigger operation
   - `SObjectType__c` (Text): SObject type
   - `RecordCount__c` (Number): Number of records processed
   - `StartTime__c` (DateTime): Start time
   - `EndTime__c` (DateTime): End time
   - `ExecutionTime__c` (Number): Execution time in milliseconds
   - `CPUTime__c` (Number): CPU time consumed
   - `DMLRows__c` (Number): DML rows consumed
   - `QueryRows__c` (Number): Query rows consumed

### Step 3: Implement ITriggerExecutable

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

### Step 4: Configure Trigger Features

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

### Step 5: Implement Trigger

Create a trigger for your object that calls the `TriggerDispatcher`:

```apex
trigger AccountTrigger on Account (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    TriggerDispatcher.run(Account.SObjectType);
}
```

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

When queueable limits are reached, the framework automatically creates `DeferredQueueableJob__c` records:

1. To set up the processor, schedule it in Setup:
```apex
DeferredJobProcessor processor = new DeferredJobProcessor();
String cronExp = '0 0 * * * ?'; // Run every hour
System.schedule('Process Deferred Jobs', cronExp, processor);
```

2. Customize the processing intervals in `TriggerSettings__c`:
```apex
TriggerSettings__c settings = TriggerSettings__c.getInstance();
settings.MinimumScheduleIntervalMinutes__c = 15; // Process every 15 minutes
settings.DeferredJobCronPrefix__c = 'ProcessDeferredJobs_';
upsert settings;
```

### Bypass and Required Permissions

Use the `BypassPermission__c` and `RequiredPermission__c` fields in `TriggerFeature__mdt` to control execution based on custom permissions:

1. Create custom permissions in Setup
2. Assign them to permission sets
3. Reference them in your trigger features:
   - `BypassPermission__c`: If the user has this permission, the handler will not execute
   - `RequiredPermission__c`: The user must have this permission for the handler to execute

### Performance Metrics

Enable performance tracking via the custom setting:

```apex
TriggerSettings__c settings = TriggerSettings__c.getInstance();
settings.IsMetricsEnabled__c = true;
upsert settings;
```

This will log detailed metrics to the `TriggerMetric__c` object, including:
- Execution time
- CPU time
- DML rows
- Query rows

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
