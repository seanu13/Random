/**
 * @description       : Trigger Helper for Modification Trigger
 * @author            : Sean Upton - sean.upton@technomile.com
 * @group             : 
 * @last modified on  : 04-04-2023
 * @last modified by  : Sean Upton - sean.upton@technomile.com
 * Modifications Log
 * Ver   Date         Author                                   Modification
 * 1.0   04-04-2023   Sean Upton - sean.upton@technomile.com   Initial Version
**/
public without sharing class TMPS_ModificationTriggerHelper {
    public TMPS_ModificationTriggerHelper() {

    }

    /**
    * @description Create Project Activity records when saving a Mod
    * @author Sean Upton - sean.upton@technomile.com | 04-04-2023 
    * @param List<TM_TOMA__Modification__c> newModsList 
    **/
    public void createProjectActivities(List<TM_TOMA__Modification__c> newModsList){
        List<Project_Activity__c> activitiesToInsert = new List<Project_Activity__c>();
        Map<Id, TM_TOMA__Contract_Vehicle__c> contractsMap = getContractRecords(newModsList);

        //Project__c
        for (TM_TOMA__Modification__c mod : newModsList){
            TM_TOMA__Contract_Vehicle__c contract = contractsMap.get(mod.TM_TOMA__Contract_Vehicle__c);

            if (contract.tmps_Project__c != null){
                Project_Activity__c activity = new Project_Activity__c(Note__c = mod.TM_TOMA__Description__c, Notify_Team__c = false, Project__c = contract.tmps_Project__c);
                activitiesToInsert.add(activity);
            }
        }

        if (!activitiesToInsert.isEmpty()){
            insert activitiesToInsert;
        }
    }

    /**
    * @description Bulkified method for retrieving Contracts related to the Mods within the trigger
    * @author Sean Upton - sean.upton@technomile.com | 04-04-2023 
    * @param List<TM_TOMA__Modification__c> newModsList 
    * @return Map<Id, TM_TOMA__Contract_Vehicle__c> 
    **/
    public Map<Id, TM_TOMA__Contract_Vehicle__c> getContractRecords(List<TM_TOMA__Modification__c> newModsList){
        Set<Id> contractIds = new Set<Id>();

        for (TM_TOMA__Modification__c mod : newModsList){
            contractIds.add(mod.TM_TOMA__Contract_Vehicle__c);
        }

        Map<Id, TM_TOMA__Contract_Vehicle__c> contractsMap = new Map<Id, TM_TOMA__Contract_Vehicle__c>([SELECT Id, tmps_Project__c FROM TM_TOMA__Contract_Vehicle__c]);

        return contractsMap;
    }
}