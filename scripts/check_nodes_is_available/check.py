import sys
import time

import paramiko

node1 = sys.argv[1]
node2 = sys.argv[2]
node3 = sys.argv[3]

user = sys.argv[4]
passw = sys.argv[5]

nodes = [node1, node2, node3]

step_count = 100
step_length = 10


def check_nodes() -> bool:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        for node in nodes:
            client.connect(hostname=node, username=user, password=passw, port=22)
            _, _, _ = client.exec_command('ls -lah')
        return True
    except Exception:
        print("Nodes not ready")
        return False


if __name__ == "__main__":
    for i in range(step_count):
        time.sleep(step_length)
        if not check_nodes():
            continue
        print(f'Nodes ready after {i * step_length} seconds')
        break
