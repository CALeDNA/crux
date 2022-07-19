import asyncio
import aiohttp
import argparse


parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
args = parser.parse_args()

filename = args.input
links = args.output


async def head(session: aiohttp.ClientSession, line: str, id_path: str):
    hasLink = False
    for i in range(1,5):
        url = f"https://sra-download.ncbi.nlm.nih.gov/traces/wgs0{i}/wgs_aux{id_path}.1.fsa_nt.gz"
        try:
            response = await session.head(url)
        except aiohttp.ClientConnectionError:
            print("Connection Error")
            response = 404
        except aiohttp.ClientError:
            print("Client Error")
            response = 404

        if(response != 404):
            if(response.status == 200):
                hasLink = True
                return url, response.content_length, line
    if not hasLink:
        return "", 0, line


async def main(lines) -> int:
    size = 0
    with open(links, 'a') as out:
        connector = aiohttp.TCPConnector(limit=100)
        timeout = aiohttp.ClientTimeout(total=300)
        async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
            tasks = []
            for line in lines:
                line = line.rstrip('\n').strip('\"').lstrip('NZ_')
                if len(line) %2 != 0: # ignores id's with odd number of letters
                    with open("misses.log", 'a') as log:
                        log.writelines(line + '\n')
                    continue
                id_path = ""

                for i in range(0,len(line),2):
                    if line[i:i+2].isdigit():
                        id_path += '/' + line
                    else:
                        id_path +=  '/' + line[i:i+2]
                id_path += '/' + line
                tasks.append((head(session=session, line=line, id_path=id_path)))

            for task in asyncio.as_completed(tasks):
                url, content_length, line = await task

                if url:
                    print(url)
                    out.writelines(url + '\n')
                    size += content_length
                else:
                    with open("misses.log", 'a') as log:
                        log.writelines(line + '\n')
        print(f"Total size: {size}")


if __name__ == '__main__':
    with open(filename, 'r') as file:
        lines = file.readlines()
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(main(lines))
    finally:
        loop.close()
