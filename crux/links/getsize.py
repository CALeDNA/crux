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
    try:
        url = url.rstrip('\n')
        response = await session.head(url)
        if response:
            return url, response.content_length
    except aiohttp.ClientConnectionError:
        print("Connection Error")
    except aiohttp.ClientError:
        print("Client Error")
    except asyncio.TimeoutError:
        print("Timeout Error")
    return url, 0


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
                    url, content_length = await task
                    if content_length != 0:
                        out.writelines(url.rstrip('\n') + ',' + str(content_length) + '\n')
                    else:
                        log.writelines(url.rstrip('\n') + ',0' + '\n')


if __name__ == '__main__':
    with open(filename, 'r') as file:
        lines = file.readlines()
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(main(lines))
    finally:
        loop.close()