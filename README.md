# Salesforce Apex Trigger Framework Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Framework Overview](#framework-overview)
3. [Key Components](#key-components)
   - [TriggerDispatcher](#triggerdispatcher)
   - [TriggerContext](#triggercontext)
   - [ITriggerExecutable](#itriggerexecutable)
   - [TriggerFeature__mdt](#triggerfeaturemdt)
   - [TriggerMetrics](#triggermetrics)
4. [Implementation Guide](#implementation-guide)
   - [Step 1: Create Custom Metadata Type](#step-1-create-custom-metadata-type)
   - [Step 2: Implement ITriggerExecutable](#step-2-implement-itriggerexecutable)
   - [Step 3: Configure Trigger Features](#step-3-configure-trigger-features)
   - [Step 4: Implement Trigger](#step-4-implement-trigger)
5. [Advanced Features](#advanced-features)
   - [Asynchronous Execution](#asynchronous-execution)
   - [Bypass and Required Permissions](#bypass-and-required-permissions)
   - [Performance Metrics](#performance-metrics)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Examples](#examples)
   - [Basic Usage](#basic-usage)
   - [Multiple Handlers](#multiple-handlers)
   - [Asynchronous Handler](#asynchronous-handler)
9. [Conclusion](#conclusion)

## Introduction

This document provides comprehensive documentation for a custom Salesforce Apex trigger framework. The framework is designed to simplify trigger management, improve code organization, and enhance maintainability of Salesforce applications. It offers a flexible and scalable approach to handling complex trigger logic across multiple objects.

## Framework Overview

The framework is built on the following key principles:

1. **Separation of Concerns**: Trigger logic is separated from the trigger itself, allowing for better organization and reusability.
2. **Configurability**: Trigger behavior is controlled through custom metadata, enabling easy management without code changes.
3. **Extensibility**: The framework supports multiple handlers per object and trigger event, allowing for modular and scalable trigger logic.
4. **Performance Monitoring**: Built-in metrics tracking helps identify and optimize performance bottlenecks.
5. **Asynchronous Execution**: Support for asynchronous trigger execution to handle complex or long-running operations.

## Key Components

### TriggerDispatcher

The `TriggerDispatcher` class is the core of the framework. It handles the execution of trigger logic based on the configured trigger features.

Key responsibilities:
- Fetches and caches trigger feature configurations
- Determines which handlers to execute based on the current trigger context
- Manages synchronous and asynchronous execution of handlers
- Handles error scenarios and permissions

### TriggerContext

The `TriggerContext` class encapsulates all relevant information about the current trigger execution, including:

- Trigger operation (insert, update, delete, undelete)
- Trigger phase (before, after)
- Old and new record lists and maps
- Helper methods for common trigger operations

### ITriggerExecutable

The `ITriggerExecutable` interface defines the contract for all trigger handlers. Any class implementing this interface can be used as a trigger handler in the framework.

### TriggerFeature__mdt

This custom metadata type stores the configuration for each trigger feature, including:

- Handler class name
- Enabled trigger events (before insert, after update, etc.)
- Execution order
- Asynchronous execution flag
- Bypass and required permissions

### TriggerMetrics

The `TriggerMetrics` class provides functionality to track and log performance metrics for trigger executions, helping identify potential performance issues.

## Implementation Guide

### Step 1: Create Custom Metadata Type

Create a custom metadata type named `TriggerFeature__mdt` with the following fields:

- `DeveloperName` (Text)
- `Handler__c` (Text)
- `IsActive__c` (Checkbox)
- `LoadOrder__c` (Number)
- `BeforeInsert__c` (Checkbox)
- `AfterInsert__c` (Checkbox)
- `BeforeUpdate__c` (Checkbox)
- `AfterUpdate__c` (Checkbox)
- `BeforeDelete__c` (Checkbox)
- `AfterDelete__c` (Checkbox)
- `AfterUndelete__c` (Checkbox)
- `Asynchronous__c` (Checkbox)
- `SObjectName__c` (Text)
- `BypassPermission__c` (Text)
- `RequiredPermission__c` (Text)

### Step 2: Implement ITriggerExecutable

Create a class that implements the `ITriggerExecutable` interface for each piece of trigger logic you want to execute:

```apex
public class AccountTriggerHandler implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        if (context.isInsert && context.isBefore) {
            // Handle before insert logic
        } else if (context.isUpdate && context.isAfter) {
            // Handle after update logic
        }
        // Add more conditions as needed
    }
}
```

### Step 3: Configure Trigger Features

Create `TriggerFeature__mdt` records for each trigger handler you want to use:

1. Go to Setup > Custom Metadata Types
2. Click "Manage Records" next to `TriggerFeature__mdt`
3. Click "New"
4. Fill in the details:
   - Label: A descriptive name (e.g., "Account Before Insert Handler")
   - DeveloperName: A unique API name (e.g., "Account_Before_Insert_Handler")
   - Handler__c: The full name of your handler class (e.g., "AccountTriggerHandler")
   - IsActive__c: Check this to enable the handler
   - LoadOrder__c: Set the execution order (lower numbers execute first)
   - BeforeInsert__c: Check if this handler should run before insert
   - SObjectName__c: The API name of the object (e.g., "Account")
5. Save the record

Repeat this process for each trigger handler you want to configure.

### Step 4: Implement Trigger

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

Note: Asynchronous execution is not allowed in before triggers.

### Bypass and Required Permissions

Use the `BypassPermission__c` and `RequiredPermission__c` fields in `TriggerFeature__mdt` to control execution based on user permissions:

- `BypassPermission__c`: If the user has this permission, the handler will not execute
- `RequiredPermission__c`: The user must have this permission for the handler to execute

### Performance Metrics

Enable performance tracking:

```apex
TriggerMetrics.enableMetrics();
```

Metrics will be logged as debug messages, which can be viewed in the debug logs.

## Best Practices

1. Keep handler logic focused and modular
2. Use meaningful names for your handler classes and trigger feature records
3. Set appropriate load orders to ensure correct execution sequence
4. Use asynchronous execution for long-running operations to avoid governor limits
5. Regularly review and optimize handler performance using TriggerMetrics
6. Use bypass and required permissions to implement fine-grained control over trigger execution

## Troubleshooting

Common issues and solutions:

1. **Handler not executing**: 
   - Check if the `TriggerFeature__mdt` record is active
   - Verify the `SObjectName__c` field is correct
   - Ensure the appropriate trigger event checkbox is selected

2. **Incorrect execution order**: 
   - Review and adjust the `LoadOrder__c` field in `TriggerFeature__mdt` records

3. **Asynchronous execution not working**: 
   - Confirm the `Asynchronous__c` field is set to true
   - Ensure the handler is not configured for before triggers

4. **Performance issues**: 
   - Enable TriggerMetrics and analyze the logs
   - Look for operations that can be bulkified or optimized

## Examples

### Basic Usage

1. Create a handler class:

```apex
public class AccountNameValidator implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        for (Account acc : (List<Account>)context.getRecords()) {
            if (String.isBlank(acc.Name)) {
                acc.Name.addError('Account name cannot be blank');
            }
        }
    }
}
```

2. Create a `TriggerFeature__mdt` record:
   - DeveloperName: Account_Name_Validator
   - Handler__c: AccountNameValidator
   - IsActive__c: True
   - LoadOrder__c: 10
   - BeforeInsert__c: True
   - BeforeUpdate__c: True
   - SObjectName__c: Account

3. Implement the trigger:

```apex
trigger AccountTrigger on Account (before insert, before update) {
    TriggerDispatcher.run(Account.SObjectType);
}
```

### Multiple Handlers

1. Create additional handler classes:

```apex
public class AccountIndustryDefaulter implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        for (Account acc : (List<Account>)context.getRecords()) {
            if (String.isBlank(acc.Industry)) {
                acc.Industry = 'Other';
            }
        }
    }
}

public class AccountRelatedContactCreator implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        List<Contact> newContacts = new List<Contact>();
        for (Account acc : (List<Account>)context.getRecords()) {
            newContacts.add(new Contact(
                AccountId = acc.Id,
                LastName = 'Primary Contact'
            ));
        }
        insert newContacts;
    }
}
```

2. Create corresponding `TriggerFeature__mdt` records for each handler.

3. The `AccountTrigger` remains the same, but now multiple handlers will execute based on the configurations.

### Asynchronous Handler

1. Create an asynchronous handler:

```apex
public class AccountAsyncProcessor implements ITriggerExecutable {
    public void execute(TriggerContext context) {
        // Note: context.getRecords() will return null in async mode
        // Use context.getRecordIds() instead
        Set<Id> accountIds = context.getRecordIds();
        
        // Perform async processing
        for (Id accountId : accountIds) {
            // Perform long-running operation or callout
        }
    }
}
```

2. Create a `TriggerFeature__mdt` record:
   - DeveloperName: Account_Async_Processor
   - Handler__c: AccountAsyncProcessor
   - IsActive__c: True
   - LoadOrder__c: 20
   - AfterInsert__c: True
   - Asynchronous__c: True
   - SObjectName__c: Account

3. The `AccountTrigger` remains the same, but now includes the after insert event:

```apex
trigger AccountTrigger on Account (before insert, after insert, before update) {
    TriggerDispatcher.run(Account.SObjectType);
}
```

## Conclusion

This Salesforce Apex Trigger Framework provides a robust and flexible solution for managing complex trigger logic. By separating concerns, enabling configuration-driven behavior, and offering advanced features like asynchronous execution and performance monitoring, it empowers developers to create maintainable and scalable Salesforce applications.

As you work with this framework, remember to keep your trigger logic modular, leverage the configuration options provided by `TriggerFeature__mdt`, and regularly review performance metrics to ensure optimal execution.

For further assistance or to report issues, please contact your Salesforce development team or system administrator.
