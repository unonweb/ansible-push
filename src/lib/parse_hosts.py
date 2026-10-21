#!/usr/bin/env python3
import sys
import yaml

def main():
    if len(sys.argv) < 2:
        sys.exit(0)
    
    playbook_path = sys.argv[1]
    try:
        with open(playbook_path, "r") as f:
            data = yaml.safe_load(f)
        
        hosts = []
        # An Ansible playbook is a list of plays
        if isinstance(data, list):
            for play in data:
                if isinstance(play, dict) and "hosts" in play:
                    h = play["hosts"]
                    if isinstance(h, list):
                        hosts.extend([str(x) for x in h if x])
                    elif h:
                        hosts.append(str(h))
                        
        print(" ".join(hosts))
    except Exception:
        sys.exit(0)

if __name__ == "__main__":
    main()