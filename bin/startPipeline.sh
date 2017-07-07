#!/bin/bash

set -e 
set -u

groupname=$1

MYINSTALLATIONDIR=$( cd -P "$( dirname "$0" )" && pwd )

#
# Source config files.
#
HOSTNAME_SHORT=$(hostname -s)
. ${MYINSTALLATIONDIR}/${groupname}.cfg
. ${MYINSTALLATIONDIR}/${HOSTNAME_SHORT}.cfg
. ${MYINSTALLATIONDIR}/sharedConfig.cfg

NGS_DNA="3.3.3"
NGS_RNA="3.2.4"

count=0 
if ls ${TMP_ROOT_DIR}/Samplesheets/*.csv 1> /dev/null 2>&1
then
	counting=$(ls ${TMP_ROOT_DIR}/Samplesheets/*.csv | wc -l)
	echo "Checking $counting files "

	for i in $(ls ${TMP_ROOT_DIR}/Samplesheets/*.csv) 
	do
  		csvFile=$(basename $i)
        	filePrefix="${csvFile%.*}"
		
		##get header to decide later which column is project
		HEADER=$(head -1 ${i})
	
		##Remove header, only want to keep samples
		sed '1d' $i > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp
		OLDIFS=$IFS
		IFS=','
		array=($HEADER)
		IFS=$OLDIFS
		count=1
	
		pipeline="DNA"
		specie="homo_sapiens"
		for j in "${array[@]}"
		do
  			if [ "${j}" == "project" ]
  	     		then
				awk -F"," '{print $'$count'}' ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp2
			elif [[ "${j}" == *"SampleType"* ]]
			then
				awk -F"," '{print $'$count'}' ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.whichPipeline
				pipeline=$(head -1 ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.whichPipeline)
	
			elif [[ "${j}" == "specie" ]]
			then
				awk -F"," '{print $'$count'}' ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.specie		
				specie=$(head -1 ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.specie)
  			elif [ "${j}" == "capturingKit" ]
  	     		then
				awk -F"," '{print $'$count'}' ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.capturingKit
	
			fi
			count=$((count + 1))
		done
	
		cat ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.tmp2 | sort -V | uniq > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.uniq.projects
	
        	PROJECTARRAY=()
        	while read line
        	do
          		PROJECTARRAY+="${line} "
	
        	done<${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.uniq.projects
		count=1
	
		cat ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.capturingKit | sort -V | uniq > ${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.uniq.capturingKits	
		miSeqRun="no"
		while read line
        	do
			if [[ "${line}" == *"CARDIO_v"* || "${line}" == *"DER_v"* || "${line}" == *"DYS_v"* || "${line}" == *"EPI_v"* || "${line}" == *"FH_v"* || "${line}" == *"LEVER_v"* || "${line}" == *"MYO_v"* || "${line}" == *"NEURO_v"* || "${line}" == *"ONCO_v"* || "${line}" == *"PCS_v"* || "${line}" == *"TID_v"* ]]
			then
				miSeqRun="yes"
				break
			fi
        	done<${TMP_ROOT_DIR}/logs/TMP/${filePrefix}.uniq.capturingKits
	
        	OLDIFS=$IFS
        	IFS=_
		set $filePrefix
        	sequencer=$2
        	run=$3
		IFS=$OLDIFS
        	LOGGER=${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.logger
	
		####
		### Decide if the scripts should be created (per Samplesheet)
		##
		#
		function finish {
        	if [ -f ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked ]
        	then
	       		echo "${filePrefix} TRAPPED"
	        	rm ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked
	        	fi
        	}
        	trap finish HUP INT QUIT TERM EXIT ERR
	
		if [[ -f ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.dataCopiedToDiagnosticsCluster || -f ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.dataCopiedToCalculonCluster ]] && [ ! -f ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.scriptsGenerated ]
        	then
               		### Step 4: Does the pipeline need to run?
               		if [ "${pipeline}" == "RNA-Lexogen-reverse" ]
               		then
               	        	echo "RNA-Lexogen-reverse" >> ${LOGGER}
               		elif [ "${pipeline}" == "RNA-Lexogen" ]
               		then
               	        	echo "RNA-Lexogen" >> ${LOGGER}
               		elif [ "${pipeline}" == "RNA" ]
               		then
				module load NGS_RNA/${NGS_RNA}
	
				projectName=""
				workflowRNA="hisat"
				build="b37"
	
				for PROJECT in ${PROJECTARRAY[@]}
                		do
               	        		projectName=${PROJECT}
					
				done
			
				echo "RNA" >> ${LOGGER}
				echo "WE ARE IN"
					
	
				#
				##      CHANGE WHEN FINISHED TESTING
				###
					EBROOTNGS_AUTOMATED=/home/umcg-rkanninga/github/NGS_Automated/
				###
				##
				#
							
				if [[ "${projectName}" == *"Lexogen"* ]]
				then
					workflowRNA="lexogen"
				fi
				# callithrix_jacchus, mus_musculus, homo_sapiens
				if [ $specie != "homo_sapiens" ]
				then
					build="b38"
				fi
				
				mkdir -p ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/
				echo "copying $EBROOTNGS_AUTOMATED/automated_RNA_generate_template.sh to ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh" >> $LOGGER		
	
				cp  $EBROOTNGS_AUTOMATED/automated_RNA_generate_template.sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh
	
			 	perl -pi -e "s|VERSIONFROMSTARTPIPELINESCRIPT|${NGS_RNA}|" ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh
	
				if [ -f ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv ]
                        	then
                            		echo "${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv already existed, will now be removed and will be replaced by a fresh copy" >> $LOGGER
                                	rm ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv
                        	fi
	
                        	cp ${TMP_ROOT_DIR}/Samplesheets/${csvFile} ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv
	
                        	cd ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/
	
                        	echo "sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh "${filePrefix}" ${build} ${specie} ${workflowRNA}"
				echo "sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh "${filePrefix}" ${build} ${specie} ${workflowRNA}" > ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.logger
                        	sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh "${filePrefix}" ${build} ${specie} ${workflowRNA} > ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.logger 2>&1
                        	cd scripts
				touch ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked
                        	sh submit.sh
				rm ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked
                       		touch ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.scriptsGenerated
	
               		elif [ "${pipeline}" == "DNA" ]
               		then
				module load NGS_DNA/${NGS_DNA}
	
				if pipelineVersion=$(module list | grep -o -P 'NGS_DNA(.+)')
				then
					echo ""
				else
					underline=`tput smul`
					normal=`tput sgr0`
					bold=`tput bold`
					printf "${bold}WARNING: there is no pipeline version loaded, this can be because this script is run manually.\nA default version of the NGS_DNA pipeline will be loaded!\n\n"
					module load $DNA
					pipelineVersion=$(module list | grep -o -P 'NGS_DNA(.+)')
					printf "The version which is now loaded is $pipelineVersion${normal}\n\n"
				fi
                       		mkdir -p ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/
	
				batching="_chr"
	
				if [ "${miSeqRun}" == "yes" ]
				then
					batching="_small"
				fi
	
				echo "copying $EBROOTNGS_AUTOMATED/automated_generate_template.sh to ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh" >> $LOGGER
                       		cp ${EBROOTNGS_AUTOMATED}/automated_generate_template.sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh
	
				perl -pi -e "s|VERSIONFROMSTARTPIPELINESCRIPT|${NGS_DNA}|" ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh
	
				if [ -f ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv ]
				then
					echo "${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv already existed, will now be removed and will be replaced by a fresh copy" >> $LOGGER
					rm ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv
				fi
	
				cp ${TMP_ROOT_DIR}/Samplesheets/${csvFile} ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/${filePrefix}.csv
	
				cd ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/
	
				sh ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.sh "${filePrefix}" ${batching} > ${TMP_ROOT_DIR}/generatedscripts/${filePrefix}/generate.logger 2>&1 
	
				cd scripts
                        	touch ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked
                        	sh submit.sh
                        	rm ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.pipeline.locked
                        	touch ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.scriptsGenerated
			fi
		fi
	
		####
		### If generatedscripts is already done, step in this part to submit the jobs (per project)
		##
		#
		if [ -f ${TMP_ROOT_DIR}/logs/${filePrefix}/${filePrefix}.scriptsGenerated ] 
		then
			for PROJECT in ${PROJECTARRAY[@]}
			do
				if [ ! -d ${TMP_ROOT_DIR}/logs/${PROJECT} ]
				then
					mkdir ${TMP_ROOT_DIR}/logs/${PROJECT}
				fi
 	
				function finishProject {
                                	if [ -f ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.locked ]
                                	then
                                        	echo "${PROJECT} TRAPPED"
                                        	rm ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.locked      
                                	fi
                        	}
				trap finishProject HUP INT QUIT TERM EXIT ERR
				
				WHOAMI=$(whoami)
				HOSTN=$(hostname)
		        	LOGGER=${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.logger
				if [[ ! -f ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.started  && ! -f ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.locked && ! -f ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.finished ]]
				then

                                        echo "${PROJECT}"

                                        touch ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.locked
                                        cd ${TMP_ROOT_DIR}/projects/${PROJECT}/run01/jobs/

                                        ## creating jobs entity
                                        echo -e "job\tproject_job\tproject\tstarted_date\tfinished_date\tstatus" >  ${TMP_ROOT_DIR}/logs/${PROJECT}/jobsPerProject.tsv
                                        grep '^processJob' submit.sh | tr '"' ' ' | awk -v pro=$PROJECT '{OFS="\t"} {print $2,pro"_"$2,pro,"","",""}' >>  ${TMP_ROOT_DIR}/logs/${PROJECT}/jobsPerProject.tsv

                                        CURLRESPONSE=$(curl -H "Content-Type: application/json" -X POST -d "{"username"="${USERNAME}", "password"="${PASSWORD}"}" https://${MOLGENISSERVER}/api/v1/login)
                                        TOKEN=${CURLRESPONSE:10:32}
                                        curl -H "x-molgenis-token:${TOKEN}" -X POST -F"file=@${TMP_ROOT_DIR}/logs/${PROJECT}/jobsPerProject.tsv" -FentityName='status_jobs' -Faction=add -Fnotify=false https://${MOLGENISSERVER}/plugin/importwizard/importFile
                                        echo "curl -H "x-molgenis-token:${TOKEN}" -X POST -F"file=@${TMP_ROOT_DIR}/logs/${PROJECT}/jobsPerProject.tsv" -FentityName='status_jobs' -Faction=add -Fnotify=false https://${MOLGENISSERVER}/plugin/importwizard/importFile"
                                
				        ## create project entity
                                        echo "project,run_id,pipeline,copy_results_prm,date" >  ${TMP_ROOT_DIR}/logs/${PROJECT}/project.csv
                                        echo "${PROJECT},${filePrefix},"DNA",," >>  ${TMP_ROOT_DIR}/logs/${PROJECT}/project.csv

                                        CURLRESPONSE=$(curl -H "Content-Type: application/json" -X POST -d "{"username"="${USERNAME}", "password"="${PASSWORD}"}" https://${MOLGENISSERVER}/api/v1/login)
                                        TOKEN=${CURLRESPONSE:10:32}
                                        curl -H "x-molgenis-token:${TOKEN}" -X POST -F"file=@${TMP_ROOT_DIR}/logs/${PROJECT}/project.csv" -FentityName='status_projects' -Faction=add -Fnotify=false https://${MOLGENISSERVER}/plugin/importwizard/importFile
                                  	echo "curl -H "x-molgenis-token:${TOKEN}" -X POST -F"file=@${TMP_ROOT_DIR}/logs/${PROJECT}/project.csv" -FentityName='status_projects' -Faction=add -Fnotify=false https://${MOLGENISSERVER}/plugin/importwizard/importFile"
                                        sleep 10
					
					sh submit.sh
	
					touch ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.started
					echo "${PROJECT} started" >> $LOGGER
					echo "${PROJECT} started"	
					printf "Pipeline: ${pipeline}\nStarttime:`date +%d/%m/%Y` `date +%H:%M`\nProject: $PROJECT\nStarted by: $WHOAMI\nHost: ${HOSTN}\n\nProgress can be followed via the command squeue -u $WHOAMI on $HOSTN.\nYou will receive an email when the pipeline is finished!\n\nCheers from the GCC :)" | mail -s "NGS_DNA pipeline is started for project $PROJECT on `date +%d/%m/%Y` `date +%H:%M`" ${EMAIL_TO}
					sleep 40
					rm -f ${TMP_ROOT_DIR}/logs/${PROJECT}/${PROJECT}.pipeline.locked
				fi
			done
		fi
	done
	else
	echo "There are no samplesheets"
fi

trap - EXIT
exit 0