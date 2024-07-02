/**
 * @description       : 
 * @author            : anisha@concret.io
 * @group             : 
 * @last modified on  : 06-25-2024
 * @last modified by  : anisha@concret.io
**/
public with sharing class CourseOfferingController {
    @AuraEnabled(cacheable=true)
    public static LearningCourse getCourseDetails(Id recordId) {
        LearningCourse course = [
            SELECT Id, Name, 
                   (SELECT Id, Name, StartDate, Price__c FROM CourseOfferings WHERE Id = :recordId)
            FROM LearningCourse
            WHERE Id IN (SELECT LearningCourseId FROM CourseOffering WHERE Id = :recordId)
        ];

        for (CourseOffering offering : course.CourseOfferings) {
            if (offering.StartDate != null) {
                Date onlyDate = offering.StartDate.date();
                offering.put('StartDate', onlyDate);
            }
        }

        return course;
    }

    @AuraEnabled
    public static List<CourseOffering> validateAndAdjustPrices(List<String> courseIds) {
      List<CourseOffering> courseList = [SELECT Id, Name, StartDate, Price__c, LearningCourse.Name FROM CourseOffering WHERE Id = :courseIds];
        System.debug('courseList'+courseList);
        return courseList;
    }

}