/**
 * @description       : 
 * @author            : Sean Upton - sean.upton@technomile.com
 * @group             : 
 * @last modified on  : 05-23-2023
 * @last modified by  : Sean Upton - sean.upton@technomile.com
 * Modifications Log
 * Ver   Date         Author                                   Modification
 * 1.0   05-23-2023   Sean Upton - sean.upton@technomile.com   Initial Version
**/
public without sharing class TMPS_CostpointProjectTriggerHandler {
    // 5/11/23 Sean Upton: sean.upton@technomile.com: added to prevent recursion
    
    
    public TMPS_CostpointProjectTriggerHandler() {

    }

    public void afterUpdate(List<Costpoint_Project__c> newProjects, Map<Id, Costpoint_Project__c> oldProjects){
        // 4/24/23 Sean Upton: sean.upton@technomile.com: contract initiation on insert
        if(!TMPS_TechnoMileUtility.isFirstRun) {
            TMPS_TechnoMileUtility.isFirstRun = true;
            TMPS_TechnoMileUtility tmu = new TMPS_TechnoMileUtility();
            tmu.isInsert = Trigger.isInsert;
            tmu.createContracts(newProjects, oldProjects);
            tmu.syncWithContracts(newProjects, oldProjects);
        }
    }

    public void afterInsert(List<Costpoint_Project__c> newProjects){
        // 4/24/23 Sean Upton: sean.upton@technomile.com: contract initiation on insert
        if(!TMPS_TechnoMileUtility.isFirstRun) {
            TMPS_TechnoMileUtility.isFirstRun = true;
            TMPS_TechnoMileUtility tmu = new TMPS_TechnoMileUtility();
            tmu.isInsert = Trigger.isInsert;
            tmu.createContracts(newProjects, null);
        }
    }
}