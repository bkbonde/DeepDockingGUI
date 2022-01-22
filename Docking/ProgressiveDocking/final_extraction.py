from multiprocessing import Pool
from contextlib import closing
import multiprocessing
import pandas as pd
import argparse
import glob
import os


def merge_on_smiles(pred_file):
    print("Merging " + os.path.basename(pred_file) + "...")

    # Read the predictions
    pred = pd.read_csv(pred_file, names=["id", "score"])
    pred.drop_duplicates()

    # Read the smiles
    smile_file = os.path.join(args.smile_dir, os.path.basename(pred_file))
    smi = pd.read_csv(smile_file, delimiter=" ", names=["smile", "id"])
    smi = smi.drop_duplicates()
    return pd.merge(pred, smi, how="inner", on=["id"]).set_index("id")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-smile_dir", required=True)
    parser.add_argument("-morgan_dir", required=True)
    parser.add_argument("-processors", required=True)
    parser.add_argument("-mols_to_dock", required=False)

    args = parser.parse_args()
    predictions = []

    print("Morgan Dir: " + args.morgan_dir)
    print("Smile Dir: " + args.smile_dir)
    for file in glob.glob(args.morgan_dir + "/*"):
        if "smile" in os.path.basename(file):
            print(" - " + os.path.basename(file))
            predictions.append(file)

    try:
        # combine the files
        print("Finding smiles...")
        print("Number of CPUs: " + str(multiprocessing.cpu_count()))
        num_jobs = min(len(predictions), int(args.processors))
        with closing(Pool(num_jobs)) as pool:
            combined = pool.map(merge_on_smiles, predictions)
    except Exception as e:
        print("While performing the final extraction, we encountered the following exception:", e)
        print("This is likely due to memory issues with multiprocessing and pickling...")
        print("We will try again with overloaded_final_extraction.py which is slower but can handle more data.")
        with open("final_phase.info", "w") as info:
            info.write("Failed")
        exit()

    # combine all dataframes
    print("Combining " + str(len(combined)) + "dataframes...")
    base = pd.concat(combined)
    combined = None

    print("Done combining... Sorting!")
    base = base.sort_values(by="score", ascending=False)

    print("Resetting Index...")
    base.reset_index(inplace=True)

    print("Finished Sorting... Here is the base:")
    print(base.head())

    # Check if we want all of the mols
    if args.mols_to_dock == "All":
        args.mols_to_dock = None

    if args.mols_to_dock is not None:
        mtd = int(args.mols_to_dock)
        print("Molecules to dock:", mtd)
        print("Total molecules:", len(base))

        if len(base) <= mtd:
            print("Our total molecules are less or equal than the number of molecules to dock -> saving all molecules")
        else:
            print(f"Our total molecules are more than the number of molecules to dock -> saving {mtd} molecules")
            base = base.head(mtd)

    print("Saving")
    # Rearrange the smiles
    smiles = base.drop('score', 1)
    smiles = smiles[["smile", "id"]]
    print("Here is the smiles:")
    print(smiles.head())
    smiles.to_csv("smiles.csv", sep=" ")

    # Rearrange for id,score
    base.drop("smile", 1, inplace=True)
    base.to_csv("id_score.csv")
    print("Here are the ids and scores")
    print(base.head())

    with open("final_phase.info", "w") as info:
        info.write("Finished")
