component displayName="jilDGML" output="false" accessors="true" {

    property name="jobs";
    property name="parser";
    property name="listGroupFilter";

    public function init(){
        variables.jobs = {};
        variables.listGroupFilter = "";
        variables.parser = new jilParser();

    }


    public function getJob(required string jobName){
        if(structKeyExists(variables.jobs,arguments.jobName)){
            return variables.jobs[arguments.jobName];
        }
        local.job = {"jobName"=arguments.jobName,"conditions"=[],"children"=[]};
        variables.jobs[arguments.jobName] = local.job;
        return local.job;
    }

    public boolean function hasChild(required struct job,childName){

    	if( !StructKeyExists(arguments.job,"children") || !ArrayLen(arguments.job.children) ){
    		return false;
    	}
    	for(local.child in arguments.job["children"]){
    		if ( local.child eq arguments.childName)	{
    			return true;
    		}
    	}

    	return false;
    }

    public function processJobFile(jilText){
        local.processText = variables.parser.removeComments(arguments.jilText);
        local.group = variables.parser.getGroup(local.processText);
        if(variables.listGroupFilter eq "" or ListFindNoCase(variables.listGroupFilter,group) ){
            local.jobName =  variables.parser.getJobName(local.processText);
            local.job = getJob(jobName);
            local.boxName = variables.parser.getBoxName(local.processText);
            // This indicates the node was created by an actual file rather than from a child or box from a child
            local.job["isFile"] = true;
            local.jobType =variables.parser.getJobType(local.processText);
            job["jobName"] =local.jobName;
            job["boxName"] =local.boxName;
            job["jobType"] =local.jobType;
            job["conditions"] = variables.parser.getConditions(local.processText);

            if( isArray(job["conditions"]) and ArrayLen(job["conditions"] )  ){
               for(local.condition in job["conditions"] )	{
               	    //we don't have to do anything here, the act of getting it creates it if necessary'
               		local.target = getJob( local.condition.target );
               }
            }

            if(lcase(jobType) != "b"){
                local.boxName = variables.parser.getBoxName(local.processText);
                if(local.boxName != ""){
                    local.box = getJob(local.boxName);
                    if( ! hasChild(local.box,local.jobName) ){
                    	arrayAppend(local.box.children,local.jobName);
                    }
                }

            }
       }
    }

    function getJobs(required string directory){
        local.arrayOfFilteredFiles = directoryList(arguments.directory, false, "name", function(path) {
            return reFindNoCase("\.jil", path);
        });

        for ( local.jilFile in local.arrayOfFilteredFiles){
            local.jilText = FileRead("#arguments.directory#\#local.jilFile#");
            processJobFile(local.jilText);
        }
        return variables.jobs;
    }

    function createNodeNoNameSpace(objXML,name,struct attributes){
        local.node = XmlElemNew( arguments.objXML,"",arguments.name);
        StructDelete(local.node.XMLAttributes,"xmlns");//Really don't need the xmlns everywhere
        if(structKeyExists(arguments,"attributes") and isStruct(arguments.attributes)){
            local.node.XMLAttributes = arguments.attributes;
       }
       return local.node;
    }

    function generateDGML( required string jobDir ){

        local.datCategories =[{"Id"="Box", "Background"="Teal"},
                              {"Id"="Job", "Background"="Aqua"},
                              {"Id"="ExternalBox","Background"="Olive"},
                              {"Id"="ExternalJob","Background"="Yellow"},
                              {"Id"="Child","Stroke"="blue","Background"="Blue"},
                              {"Id"="Conditions","Stroke"="Purple","Background"="Purple"},
                              {"Id"="s_condition","Stroke"="Green","Background"="Green"},
                              {"Id"="f_condition","Stroke"="Red","Background"="Red"},
                              {"Id"="t_condition","Stroke"="Maroon","Background"="Maroon"},
                              {"Id"="d_condition","Stroke"="Black","Background"="Black"},
                              {"Id"="n_condition","Stroke"="Orange","Background"="Orange"},
                              {"id"="Contains","Label"="Box Container","IncomingActionLabel"="Contained By","IsContainment"="True","OutgoingActionLabel"="Contained By"}
                             ];



        local.objDGML = XMLNew();
        local.xmlRoot = XmlElemNew( local.objDGML, "http://schemas.microsoft.com/vs/2009/dgml", "DirectedGraph" );
        local.objDGML.xmlRoot = local.xmlRoot;

        local.categories = createNodeNoNameSpace(local.objDGML,"Categories");
        for(local.datCategory in local.datCategories ){
            ArrayAppend(local.categories.XmlChildren, createNodeNoNameSpace(local.objDGML,"Category",local.datCategory));
        }
        local.objDGML.xmlRoot.categories= local.categories;
        local.nodes = createNodeNoNameSpace(local.objDGML,"Nodes");
        local.links = createNodeNoNameSpace(local.objDGML,"Links");
        getJobs(arguments.jobDir);

        for (local.jobName in variables.jobs){
           local.job = variables.jobs[local.jobName];

            if( (StructKeyExists(local.job,"jobType") && lcase(local.job.jobType) == 'b' ) || right(local.jobName,3) == "_BX" ){
                local.nodeCategory = ( StructKeyExists(local.job,"isFile") ? "Box" : "ExternalBox");
                // Make a container
                local.nodeContainer = createNodeNoNameSpace(local.objDGML,"Node",{"Id"="#local.job.jobName#_container","Label"="#local.job.jobName# Box","Group"="Expanded"});
				ArrayAppend(local.nodes.XmlChildren, local.nodeContainer);
                local.isContainer = true;

            }else{
                local.nodeCategory = ( StructKeyExists(local.job,"isFile") ? "Job" : "ExternalJob");
                local.isContainer = false;
            }


            local.node = createNodeNoNameSpace(local.objDGML,"Node",{"Id"=local.job.jobName,"Label"=local.job.jobName,"Category"= local.nodeCategory});
			if( local.isContainer ){
			 	local.boxLink = createNodeNoNameSpace(local.objDGML,"Link",{"Source"="#local.job.jobName#_container","Target"=local.job.jobName,"Category"="Contains"});
			     ArrayAppend(local.links.XmlChildren, local.boxLink);
			}

            ArrayAppend(local.nodes.XmlChildren, local.node);

            if(isArray(local.job.conditions) and ArrayLen(local.job.conditions) ){

                for(local.condition in local.job.conditions){

                   local.link = createNodeNoNameSpace(local.objDGML,"Link",{"Source"=local.job.jobName,"Target"=local.condition.target,"Label"="condition #local.condition.operator# #local.condition.status#","Category"="#local.condition.status#_condition"});
                   ArrayAppend(local.links.XmlChildren, local.link);
                }
            }

			if(isArray(local.job.children) and ArrayLen(local.job.children) ){

				for(local.child in local.job.children){
					  local.childLink = createNodeNoNameSpace(local.objDGML,"Link",{"Source"=local.job.jobName,"Target"=local.child,"Label"="child","Category"="Child"});
                      ArrayAppend(local.links.XmlChildren, local.childLink);
                      local.childContainerLink = createNodeNoNameSpace(local.objDGML,"Link",{"Source"="#local.job.jobName#_container","Target"=local.child,"Category"="Contains"});
				      ArrayAppend(local.links.XmlChildren, local.childContainerLink);
				}
			}
        }



        local.objDGML.xmlRoot.links= local.links;
        local.objDGML.xmlRoot.nodes= local.nodes;

        FileWrite("#expandPath("../")#\AutosysJobs.DGML",local.objDGML);

    }

}