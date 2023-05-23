/**
 * @description       : 
 * @author            : Sean Upton - sean.upton@technomile.com
 * @group             : 
 * @last modified on  : 05-23-2023
 * @last modified by  : Sean Upton - sean.upton@technomile.com
 * Modifications Log
 * Ver   Date         Author                                   Modification
 * 1.0   05-18-2023   Sean Upton - sean.upton@technomile.com   Initial Version
**/
public without sharing class TMPS_ContractTriggerHelper {
    public static Boolean isFirstRun = false;
    public TMPS_ContractTriggerHelper() {

    }

    /**
    * @description Check if values change for Contract fields which should sync to the project
    * @author Sean Upton - sean.upton@technomile.com | 05-18-2023 
    * @param List<TM_TOMA__Contract_Vehicle__c> newList 
    * @param Map<Id TM_TOMA__Contract_Vehicle__c> oldMap 
    **/
    public void syncWithProjects(List<TM_TOMA__Contract_Vehicle__c> newList, Map<Id, TM_TOMA__Contract_Vehicle__c> oldMap){
        TMPS_TechnoMileUtility tmu = new TMPS_TechnoMileUtility();
        List<tmps_TechnoMile_Data_Mappings__mdt> fieldMappings = tmu.getFieldMappings('Project');
        List<Costpoint_Project__c> projectsToUpdate = new List<Costpoint_Project__c>();

        for (TM_TOMA__Contract_Vehicle__c contract : newList){
            Boolean projectUpdated = false;
            if (contract.tmps_Project__c != null){
                TM_TOMA__Contract_Vehicle__c oldContract = oldMap.get(contract.Id);
                Costpoint_Project__c project = new Costpoint_Project__c(Id = contract.tmps_Project__c);
                // looping over fields for dynamic value checking
                for (tmps_TechnoMile_Data_Mappings__mdt mapping : fieldMappings){
                    if (contract.get(mapping.Contract_Field__c) != oldContract.get(mapping.Contract_Field__c)){
                        project.put(mapping.Project_Field__c, contract.get(mapping.Contract_Field__c));
                        projectUpdated = true;
                    }
                }

                if (projectUpdated){
                    projectsToUpdate.add(project);
                }
            }
        }

        if (!projectsToUpdate.isEmpty()){
            update projectsToUpdate;
        }
    }
}