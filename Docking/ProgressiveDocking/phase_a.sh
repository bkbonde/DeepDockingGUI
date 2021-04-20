#!/bin/bash
#SBATCH --cpus-per-task=24
#SBATCH --partition=normal
#SBATCH --ntasks=1
#SBATCH --mem=0               # memory per node
#SBATCH --job-name=phase_a
#SBATCH --output=slurm-%x.%j.out
#SBATCH --error=slurm-%x.%j.err

# Save the passed args
t_cpu=$1  # The total processors
project_path=$2  # the path to the project dir
project_name=$3  # the project name
top_n=$4  # Final number of molecules to extract
current_it=$5  # current iteration when running phase_a
current_phase=$6  # current phase when running phase_a
mols_to_dock=$7  # Number of mols to dock (should be same as in logs)
final_iteration=$8  # the total number of iterations we should run
local_path=$9  # the path to the scripts
path_to_auto_dock=${10}  # the path to auto dock
path_to_fld_file=${11}  # path to the fld grid file
num_energy_evaluations=${12}  # number of energy evaluations for docking
num_runs=${13}  # number of runs for docking
chunk_size=${14}  # the size of the chunks for phase 2
percent_fist_mol=${15}
threshold=${16}
percent_last_mol=${17}
extension=".smi"


echo Passed Args:
echo  - Total CPUs: $t_cpu
echo  - Project Path: $project_path
echo  - Project Name: $project_name
echo  - Top N: $top_n
echo  - Current Iteration: $current_it
echo  - Current Phase: $current_phase
echo  - Mols To Dock: $mols_to_dock
echo  - Final Iteration: $final_iteration
echo  - Local Path: $local_path
echo  - Path To Autodock: $path_to_auto_dock
echo  - Path To FLD File: $path_to_fld_file
echo  - Number Of Energy Evaluations: $num_energy_evaluations
echo  - Number Of Autodock GPU Runs: $num_runs
echo  - Chunk Size: $chunk_size
echo  - Percent First Mol: $percent_fist_mol
echo  - Threshold: $threshold
echo  - Percent Last Mol: $percent_last_mol


# Grab everything from the logs file
file_path=`sed -n '1p' $2/$3/logs.txt`
protein=`sed -n '2p' $2/$3/logs.txt`
#n_mol=`sed -n '9p' $2/$3/logs.txt`
#morgan_directory=`sed -n '4p' $2/$3/logs.txt`
#smile_directory=`sed -n '5p' $2/$3/logs.txt`
#sdf_directory=`sed -n '6p' $2/$3/logs.txt`
#docking_method=`sed -n '7p' $2/$3/logs.txt`

echo Job ID: $SLURM_JOBID
echo Current Phase: $current_phase

for (( n_it=$current_it; n_it<=$final_iteration; n_it++ ))
do

	if [ $n_it == $final_iteration ];then is_last=Yes;else is_last=No;fi

	echo ""
  echo "|=================================================================|"
  echo "                          ITERATION $n_it                          "
  echo "|=================================================================|"
  echo ""

  if [ $is_last == Yes ];
  then
      echo ""
	    echo '<====================IS FINAL ITERATION====================>'
      echo ""
  fi

  if [ $current_phase == 1 ]
	then
	  # Signify Start
	  echo ""
	  echo '<====================PHASE 1====================>'
	  echo ""

#		python $local_path/phase_maker.py -tpos $t_cpu -pf phase_1
		python jobid_writer.py -file_path $project_path/$project_name -n_it $n_it -jid phase_1 -jn phase_1.sh
		sbatch $local_path/phase_1.sh $n_it $t_cpu $project_path $project_name $mols_to_dock $local_path
		python $local_path/check_phase.py -pf phase_1.sh -itr $file_path/$protein/iteration_$n_it

		# Signify Complete
		echo ""
	  echo '<====================FINISHED====================>'
		echo ""
		echo ""
		((++current_phase))
	fi
	if [ $current_phase == 2 ]
	then

	  # Signify Start
	  echo ""
	  echo '<====================PHASE 2====================>'
	  echo ""

#		python $local_path/phase_maker.py -tpos $t_cpu -pf phase_2
		python jobid_writer.py -file_path $project_path/$project_name -n_it $n_it -jid phase_2 -jn phase_2.sh
		sbatch $local_path/phase_2.sh $extension $chunk_size $local_path $project_path/$project_name $n_it
		python $local_path/check_phase.py -pf phase_2.sh -itr $file_path/$protein/iteration_$n_it

		# Signify Complete
		echo ""
	  echo '<====================FINISHED====================>'
		echo ""
		echo ""
		((++current_phase))
	fi
	if [ $current_phase == 3 ]
	then

	  # Signify Start
	  echo ""
	  echo '<====================PHASE 3====================>'
	  echo ""

		python jobid_writer.py -file_path $project_path/$project_name -n_it $n_it -jid phase_3 -jn phase_3.sh
    sbatch $local_path/phase_3.sh $path_to_fld_file $num_energy_evaluations $num_runs $path_to_auto_dock $project_path/$project_name $n_it $local_path
    python $local_path/check_phase.py -pf phase_3.sh -itr $file_path/$protein/iteration_$n_it

		# Signify Complete
		echo ""
	  echo '<====================FINISHED====================>'
		echo ""
		echo ""

		((++current_phase))
	fi
	if [ $current_phase == 4 ]
	then
	  # Signify Start
	  echo ""
	  echo '<====================PHASE 4====================>'
	  echo ""

#		python $local_path/phase_maker.py -tpos $t_cpu -pf phase_4
		python jobid_writer.py -file_path $project_path/$project_name -n_it $n_it -jid phase_4 -jn phase_4.sh
		sbatch $local_path/phase_4.sh $n_it $t_cpu $project_path/$project_name $is_last $final_iteration $local_path $percent_fist_mol $threshold $percent_last_mol
		python $local_path/check_phase.py -pf phase_4.sh -itr $file_path/$protein/iteration_$n_it

		# Signify Complete
		echo ""
	  echo '<====================FINISHED====================>'
		echo ""

		((++current_phase))
	fi
	if [ $current_phase == 5 ]
	then

	  # Signify Start
	  echo ""
	  echo '<====================PHASE 5====================>'
	  echo ""

		python jobid_writer.py -file_path $project_path/$project_name -n_it $n_it -jid phase_5 -jn phase_5.sh
		sbatch $local_path/phase_5.sh $n_it $project_path/$project_name $local_path $t_cpu
		python $local_path/check_phase.py -pf phase_5.sh -itr $file_path/$protein/iteration_$n_it

		# Signify Complete
		echo ""
	  echo '<====================FINISHED====================>'
		echo ""

		current_phase=1
	fi

	t_remaining=`sed -n '7p' $file_path/$protein/iteration_$n_it/best_model_stats.txt`
	echo Total Remaining: $t_remaining
	t_remaining="$(cut -d',' -f5 <<<"$t_remaining")"
	echo Total Remaining: $t_remaining
	if [ ${t_remaining%.*} -lt $mols_to_dock ];then break;fi

	  # Signify Iteration Complete
  echo ""
  echo "|================================================================|"
  echo "|                       ITERATION Complete                       |"
  echo "|================================================================|"
  echo ""
  echo ""

done
python $local_path/phase_changer.py -pf phase_a.sh -itr $file_path/$protein


# Finished Run:
echo ""
echo "|================================================================|"
echo "|                       RUNNING FINAL PHASE                      |"
echo "|================================================================|"
echo ""

# Run the final phase
final_phase=$project_path/$project_name/iteration_$final_iteration/final_phase.info
touch $final_phase
echo Pending > $final_phase
sbatch final_extraction.sh $project_path/$project_name $t_cpu $final_iteration $local_path $top_n >> $final_phase

echo ""
echo "|================================================================|"
echo "|                      FINISHED DEEP DOCKING                     |"
echo "|================================================================|"
echo ""

# sbatch final_extraction.sh /groups/cherkasvgrp/share/progressive_docking/development/pd_python_pose_v2/test_DD_installation/DeepDockingProjects/t2000 24 6 /groups/cherkasvgrp/share/progressive_docking/development/pd_python_pose_v2/test_DD_installation/DeepDocking/ 10000