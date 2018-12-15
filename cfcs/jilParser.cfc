component displayName="jilParser" output="false" accessors="true" {

    property name="lstconditions";
    property name="jREgEx";


    public function init(){
        variables.jRegEx = createObject("component","AutoSysVisualizer.cfcs.jRegEx");
        variables.lstconditions ="success,failure,terminated,done,notrunning";//leaving out exitcode for now
    }

    public function standardizeConditions(string jilText){
        local.result = arguments.jilText;

        for(local.condition in variables.lstconditions){
            local.conditionReg =  "#ucase(local.condition)#\(|#local.condition#\(|#ucase(left(local.condition,1))#\(";
            local.result = variables.jRegEx.jreReplaceAll(local.result,local.conditionReg,left(local.condition,1) & "(");
        }

        return local.result;
    }

    public  function removeComments(string jilText){
        local.commentsReg ="/[*]([^*]|[\r\n]|([*]+([^*/]|[\r\n])))*[*]+/";
        return  variables.jRegEx.jreReplaceAll(arguments.jilText,local.commentsReg,"");
    }

    private function getMatchedResult(result,index){
        try{
            if(StructKeyExists(arguments,"result") && isArray(arguments.result) ){
                return arguments.result[1][arguments.index];
            }
            return "";

        }catch(any e){
            return "";
        }

    }

    public function getGroup(string jilText){
        local.groupReg = "group: (\w*)";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.groupReg);
        return ucase(getMatchedResult(local.result,1));
    }

    public function getJobName(string jilText){
        local.jobReg = "(insert_job|update_job): (\w+) ";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.jobReg);
        return ucase(getMatchedResult(local.result,2));
    }

     public function getJobType(string jilText){
        local.jobTypeReg = "job_type: +(\w)\s|$";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.jobTypeReg);
        return ucase(getMatchedResult(local.result,1));
    }

    public  function getBoxName(string jilText){
        local.boxNameReg = "box_name: +(\w+)";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.boxNameReg);
        return ucase(getMatchedResult(local.result,1));
    }

    public function getConditions(string jilText){
        local.conditionReg = "condition: +(.*)";
        local.result = [];
        local.jobName = getJobName(arguments.jilText);
        local.regMatches = variables.jRegEx.jreMatchGroups(arguments.jilText,local.conditionReg);
        if( ArrayLen(local.regMatches) && StructKeyExists(local.regMatches[1],1) ){
            local.conditions = standardizeConditions(local.regMatches[1][1]);
            local.andReg = " +AND|and|\&\s+";

            local.operator = variables.jRegEx.jreFind(local.conditions,local.andReg) > 0 ? "and"  :"or";
            local.aryConditions = variables.jRegEx.jreSplit(local.conditions," +(\&|AND|and|OR|or) +");
            if(ArrayLen(local.aryConditions) lt 2){
            	local.operator = "";
            }
            for(local.condition in local.aryConditions){
                local.props = variables.jRegEx.jreMatchGroups(local.condition,"(.*)\((.*)\)");
               if(arrayLen(local.props)){
                  local.condition = {"operator"=local.operator,"status"=getMatchedResult(local.props,1),"target"=ucase(getMatchedResult(local.props,2))};
                  arrayAppend(local.result,local.condition);
               }
            }
        }
        return result;
    }

    public function getDaysOfWeek(string jilText){
        local.daysReg = "days_of_week: +(.*)\S";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.daysReg);
        return getMatchedResult(local.result,1);
    }

    public function getTimeZone(string jilText){
        local.timeZoneReg = "timezone: +(.*)[\S|\s|$]";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.timeZoneReg);
        return getMatchedResult(local.result,1);
    }

    public function getStartTimes(string jilText){
        local.timeZoneReg = "start_times: +(.*)\S";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.timeZoneReg);
        return getMatchedResult(local.result,1);
    }

    public function getTokens(string jilText){
        local.tokenReg = "\$\{([A-Za-z\.]*)\}";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,tokenReg);
        local.tokens = [];
        for(local.token in local.result){
            arrayAppend(local.tokens,local.token[1]);
        }
       return local.tokens;
    }

    public function getDescription(string jilText){
        local.descriptReg = "description: +(.*)";
        local.result = variables.jRegEx.jreMatchGroups(arguments.jilText,local.descriptReg);
        return getMatchedResult(local.result,1);
    }


}