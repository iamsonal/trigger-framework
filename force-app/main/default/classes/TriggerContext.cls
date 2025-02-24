/**
 * Created by sonal on 2024-09-27.
 */

public class TriggerContext {
    public TriggerOperation operation { get; private set; }
    public List<SObject> oldList { get; private set; }
    public List<SObject> newList { get; private set; }
    public Map<Id, SObject> oldMap { get; private set; }
    public Map<Id, SObject> newMap { get; private set; }
    public Boolean isExecuting { get; private set; }
    public Boolean isInsert { get; private set; }
    public Boolean isUpdate { get; private set; }
    public Boolean isDelete { get; private set; }
    public Boolean isUndelete { get; private set; }
    public Boolean isBefore { get; private set; }
    public Boolean isAfter { get; private set; }
    public Integer size { get; private set; }
    public Boolean isAsyncMode { get; private set; }
    private Set<Id> recordIds;
    public String sObjectName { get; private set; }

    public TriggerContext(
        TriggerOperation operation,
        List<SObject> oldList,
        List<SObject> newList,
        Map<Id, SObject> oldMap,
        Map<Id, SObject> newMap,
        Boolean isExecuting,
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isDelete,
        Boolean isUndelete,
        Boolean isBefore,
        Boolean isAfter,
        Integer size,
        Boolean isAsyncMode,
        String sObjectName
    ) {
        this.operation = operation;
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete;
        this.isUndelete = isUndelete;
        this.isBefore = isBefore;
        this.isAfter = isAfter;
        this.size = size;
        this.isAsyncMode = isAsyncMode;
        this.sObjectName = sObjectName;

        if (isAsyncMode) {
            this.oldList = null;
            this.newList = null;
            this.oldMap = null;
            this.newMap = null;
            this.isExecuting = false;

            this.recordIds = new Set<Id>();
            if (this.isDelete) {
                if (Trigger.old != null) {
                    for (SObject record : Trigger.old) {
                        this.recordIds.add(record.Id);
                    }
                }
            } else if (Trigger.new != null) {
                for (SObject record : Trigger.new) {
                    this.recordIds.add(record.Id);
                }
            }
            this.size = this.recordIds.size();
        } else {
            this.oldList = oldList;
            this.newList = newList;
            this.oldMap = oldMap;
            this.newMap = newMap;
            this.isExecuting = isExecuting;

            this.size = newList != null ? newList.size() : oldList != null ? oldList.size() : 0;

            this.recordIds = (this.isInsert ||
                this.isUpdate ||
                this.isUndelete)
                ? (newMap != null ? newMap.keySet() : new Set<Id>())
                : (oldMap != null ? oldMap.keySet() : new Set<Id>());
        }
    }

    /**
     * Returns the list of new or old SObjects based on the operation type.
     * For insert, update, or undelete operations, it returns the list of new SObjects.
     * For other operations, it returns the list of old SObjects.
     * In async mode, always returns null as full records are unavailable. Handlers must use getRecordIds() in async mode instead.
     */
    public List<SObject> getRecords() {
        if (this.isAsyncMode) {
            return null; // No access to records in async mode
        }
        return (this.isInsert || this.isUpdate || this.isUndelete) ? this.newList : this.oldList;
    }

    /**
     * Returns the set of record IDs based on the operation type.
     * For insert, update, or undelete operations, it returns the set of new record IDs.
     * For other operations, it returns the set of old record IDs.
     */
    public Set<Id> getRecordIds() {
        return this.recordIds;
    }

    /**
     * Checks if a specific field of an SObject has changed.
     * Returns true if the operation is an insert or if the field's current value is different from its old value.
     * In async mode, always returns false as old values are unavailable.
     */
    public Boolean isChanged(SObject record, Schema.SObjectField field) {
        if (this.isAsyncMode) {
            return false; // No change tracking in async mode
        }
        return this.isInsert || record.get(field) != this.oldMap.get(record.Id).get(field);
    }

    /**
     * Checks if the current operation is a before insert.
     * Returns true if the operation is before and is an insert.
     */
    public Boolean beforeInsert() {
        return this.isBefore && this.isInsert;
    }

    /**
     * Checks if the current operation is an after insert.
     * Returns true if the operation is after and is an insert.
     */
    public Boolean afterInsert() {
        return this.isAfter && this.isInsert;
    }

    /**
     * Checks if the current operation is a before update.
     * Returns true if the operation is before and is an update.
     */
    public Boolean beforeUpdate() {
        return this.isBefore && this.isUpdate;
    }

    /**
     * Checks if the current operation is an after update.
     * Returns true if the operation is after and is an update.
     */
    public Boolean afterUpdate() {
        return this.isAfter && this.isUpdate;
    }

    /**
     * Checks if the current operation is a before delete.
     * Returns true if the operation is before and is a delete.
     */
    public Boolean beforeDelete() {
        return this.isBefore && this.isDelete;
    }

    /**
     * Checks if the current operation is an after delete.
     * Returns true if the operation is after and is a delete.
     */
    public Boolean afterDelete() {
        return this.isAfter && this.isDelete;
    }

    /**
     * Checks if the current operation is an after undelete.
     * Returns true if the operation is after and is an undelete.
     */
    public Boolean afterUndelete() {
        return this.isAfter && this.isUndelete;
    }
}
