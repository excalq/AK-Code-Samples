"""Counts the unique words of a text file, using in-memory hash table
   Prints stats about total word count and top 100 words

   Syntax errors from raw code: 1
"""
import sys
import os
from collections import Counter
import string # se:2
from typing import List
from pprint import pprint

def parseargs(args) -> str: # se:0
    if not args:
        print("Please pass the name of a text file as the first argument.")
        sys.exit()

    txtfile = args[1]

    if not os.path.isfile(txtfile):
        print(f"The file {txtfile} is not a valid text file!") # se:1
        sys.exit()

    return txtfile


def main(args: List[str]) -> None:
    txtfile: str = parseargs(args)
    print(f"Reading file: {txtfile}")

    wordcount = 0
    word_table = Counter()
    strip_punctuation = str.maketrans('', '', string.punctuation) # se:4

    with open(txtfile) as file:
        for line in file.readlines():
            for word in line.strip().split(' '):
                wordcount += 1
                word_sanitized = word.translate(strip_punctuation)
                word_table[word_sanitized] += 1

    print(f"File: {txtfile} wordcount: {wordcount:,}")
    print(f"Top 100 words:")
    [print(f"{w[0]:<20}: {w[1]}") for w in word_table.most_common(100)]


if __name__ == "__main__":
    main(sys.argv) # se:3