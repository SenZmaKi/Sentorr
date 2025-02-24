import threading
import time
import requests
from tqdm import tqdm

rqbit_home_url = "http://127.0.0.1:3000"
magnet_uri = "magnet:?xt=urn:btih:EC34C231DDE3E92D8D26A17C223152C8541295AA&dn=Oppenheimer%20(2023)%20%5B1080p%5D%20%5BBluRay%5D%20%5B5.1%5D&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.bittor.pw%3A1337%2Fannounce&tr=udp%3A%2F%2Fpublic.popcorn-tracker.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.dler.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969&tr=udp%3A%2F%2Fopen.demonii.com%3A1337%2Fannounce"
torrent_init_wait_time = 5

def add_torrent() -> int:
    print("Adding torrent...")
    add_torrent_url = f"{rqbit_home_url}/torrents"
    params = {
        "is_url": "true" ,
        "overwrite": "true"
    }
    payload = {
         "torrent_id": magnet_uri
    }
    resp = requests.post(add_torrent_url, params=params, json=payload)
    if not resp.ok:
        raise Exception(f"Failed to add torrent\nResponse status code: {resp.status_code}\nResponse text: {resp.text}")
    print(f"Response status code: {resp.status_code}")
    resp_json = resp.json()
    print(f"Added torrent: {resp_json}")
    print(f"Waiting for {torrent_init_wait_time}s for torrent to initialize...")
    time.sleep(torrent_init_wait_time)
    return resp_json["id"]

def download_torrent(torrent_id: int) -> None:
    print()
    print("Downloading torrent...")
    download_torrent_url = f"{rqbit_home_url}/torrents/{torrent_id}/stream/0"
    with requests.get(download_torrent_url, stream=True) as resp:
        if not resp.ok:
                raise Exception(f"Failed to download torrent: {resp.text}")
        print(f"Response status code: {resp.status_code}")
        print(f"Response headers: {resp.headers}")
        print(f"Response content type: {resp.headers.get('Content-Type')}")
        print(f"Response content length: {resp.headers.get('Content-Length')}")
        total_size = int(resp.headers.get("Content-Length", 0))  
        with open("test.mkv", "wb") as f, tqdm(
            total=total_size, unit="B", unit_scale=True, desc="Downloading"
        ) as progress_bar:
            chunk_size_kibs = 10 * 1024
            for chunk in resp.iter_content(chunk_size=chunk_size_kibs):
                    f.write(chunk)
                    progress_bar.update(len(chunk))

if __name__ == "__main__":
    torrent_id = add_torrent()
    # thread = threading.Thread(target=download_torrent, args=(torrent_id,), daemon=True)
    # thread.start()
    # # To honour KeyboardInterrupt
    # while thread.is_alive():
    #     time.sleep(0.1)