import asyncio
import aiohttp
import argparse

# python chunks_size.py --input multchunks --output chunklinks
parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
args = parser.parse_args()

filename = args.input
links = args.output



async def head(session: aiohttp.ClientSession, url: str):
    currSize = 2
    linksList = []
    try:
        for i in range(2,33):
            urlChunk = url.replace(".2.", f".{i}.").rstrip('\n')
            response = await session.head(urlChunk)
            if response:
                currSize += int(response.content_length)
                linksList.append(urlChunk)
                return url, currSize, linksList
    except aiohttp.ClientConnectionError:
        print("Connection Error")
        response = 404
    except aiohttp.ClientError:
        print("Client Error")
        response = 404
    except asyncio.TimeoutError:
        print("Timeout Error")
        response = 404
    return url, currSize, linksList


async def main(lines) -> int:
    size = 0
    with open(links, 'a') as out:
        with open("chunklinks.log", 'a') as log:
            connector = aiohttp.TCPConnector(limit=100)
            timeout = aiohttp.ClientTimeout(total=None)
            async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
                tasks = []
                for link in lines:
                    tasks.append((head(session=session, url=link)))
                for task in asyncio.as_completed(tasks):
                    url, content_length, linksList = await task
                    size += content_length
                    for l in linksList:
                        out.writelines(l + '\n')
                    log.writelines(url + ' ' + str(len(linksList)) + '\n')
        print(f"Total size: {size}")


if __name__ == '__main__':
    with open(filename, 'r') as file:
        lines = file.readlines()
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(main(lines))
    finally:
        loop.close()
