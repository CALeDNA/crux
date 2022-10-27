import asyncio
import aiohttp
import argparse


parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
args = parser.parse_args()

filename = args.input
links = args.output


async def head(session: aiohttp.ClientSession, url: str):
    hasLink = False
    try:
        response = await session.head(url)
    except aiohttp.ClientConnectionError:
        print("Connection Error")
        response = 404
    except aiohttp.ClientError:
        print("Client Error")
        response = 404
    except:
        print("Something went wrong")
        response = 404

    if(response != 404):
        if(response.status == 200):
            hasLink = True
            return url, response.content_length
    if not hasLink:
        return url, 0


async def main(lines) -> int:
    size = 0
    with open(links, 'a') as out:
        connector = aiohttp.TCPConnector(limit=100)
        timeout = aiohttp.ClientTimeout(total=None)
        async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
            tasks = []
            for link in lines:
                link = link.replace(".1.", ".2.").rstrip('\n')
                tasks.append((head(session=session, url=link)))

            for task in asyncio.as_completed(tasks):
                url, content_length = await task
                print(url, content_length)
                if content_length != 0:
                    print(url)
                    out.writelines(url + '\n')
                    size += content_length
                else:
                    with open("one_chunk", 'a') as log:
                        log.writelines(url + '\n')
        print(f"Total size: {size}")


if __name__ == '__main__':
    with open(filename, 'r') as file:
        lines = file.readlines()
    loop = asyncio.get_event_loop()
    try:
        loop.run_until_complete(main(lines))
    finally:
        loop.close()
