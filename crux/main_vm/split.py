from collections import defaultdict
import argparse
import os


parser = argparse.ArgumentParser(description='')
parser.add_argument('--chunks', type=int)
parser.add_argument('--cores', type=int)
parser.add_argument('--input', type=str)
parser.add_argument('--output', type=str)
args = parser.parse_args()

def even_split(lst, chunks):
    lst.sort()
    total_sum = sum(lst)
    avg_sum = total_sum/float(chunks)

    chunklists = [[] for x in range(chunks)]
    chunksums = [0] * chunks
    
    while lst:
        # pop the last element from sorted array
        last = lst.pop(-1)

        # append popped element to list with the lowest sum
        min_index = get_minindex(chunksums)
        chunklists[min_index].append(last)
        chunksums[min_index] += last
    return chunklists


def get_minindex(inputlist):
    #get the minimum value in the list
    min_value = min(inputlist)
    #return the index of minimum value 
    min_index=inputlist.index(min_value)
    return min_index





with open(args.input, 'r') as file:
    lines = file.readlines()

lst = []
urlDict = defaultdict(None)
for line in lines:
    if line.split(",")[1].rstrip('\n') == 'None':
        continue
    size = int(line.split(",")[1].rstrip('\n'))
    url = line.split(',')[0]
    lst.append(size)
    if size in urlDict:
        urlDict[size].append(url)
    else:
        urlDict[size] = [url]

# print(urlDict)
# print(lst)
# print(sum(lst))
lst.sort()
# print(lst)

chunklinks = even_split(lst, args.chunks * args.cores)
counter = 0
chunkcounter = 0
for arr in chunklinks:
    print(sum(arr))
    core = "%02d" % (counter)
    if counter == 0:
        vm = "%02d" % (chunkcounter)
        os.makedirs(f'{args.output}/chunk{vm}')
        chunkcounter += 1
    with open(f'{args.output}/chunk{vm}/{core}', 'w') as out:
        for size in arr:
            out.writelines(urlDict[size][-1] + '\n')
            urlDict[size].pop()
    counter += 1
    counter %= args.cores
