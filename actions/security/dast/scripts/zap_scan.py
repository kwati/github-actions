#!/usr/bin/env python
# References:
#  https://github.com/zaproxy/zaproxy/wiki/ApiGen_Index
#  https://www.zaproxy.org/docs/api/?python#exploring-the-app

import argparse
import time
from pprint import pprint
from zapv2 import ZAPv2
import os
import requests

def initialize_zap(apikey, proxy_host, proxy_port):
    proxies = {'http': f'http://{proxy_host}:{proxy_port}', 'https': f'http://{proxy_host}:{proxy_port}'}
    return ZAPv2(apikey=apikey, proxies=proxies)

def write_report(filename, content):
    with open(filename, 'w') as f:
        f.write(content)
        
def access_target(zap, target):
    print('Accessing target {}'.format(target))
    zap.urlopen(target)
    # Give the sites tree a chance to get updated
    time.sleep(5)

def delete_alerts(apikey, proxy_host, proxy_port):
    print("Cleaning Alert Space")
    url = f'http://{proxy_host}:{proxy_port}/JSON/alert/action/deleteAllAlerts/?apikey={apikey}'
    headers = {
        'Accept': 'application/json'
    }
    try:
        response = requests.get(url, headers=headers)
        # Check the response status code
        if response.status_code == 200:
            print("All alerts deleted successfully.")
        else:
            print("Failed to delete alerts. Status code:", response.status_code)

    except requests.exceptions.ConnectionError as e:
        print("Connection error:", e)
    except Exception as e:
        print("An error occurred:", e)


def spider_scan(apikey, target, proxy_host, proxy_port):
    access_target(zap, target)
    scanID = zap.spider.scan(target)
    while int(zap.spider.status(scanID)) < 100:
        # Poll the status until it completes
        print('Spider progress %: {}'.format(zap.spider.status(scanID)))
        time.sleep(1)
    
    # Retrieve alerts after spider scan
    alerts = zap.core.alerts()
    
    # Filter alerts by high and medium risk levels
    
    # Generate HTML report based on the current state of ZAP
    html_report = zap.core.htmlreport()
    report_filename = 'spider_report.html'
    report_path = os.path.join(os.getcwd(), report_filename)  # Set your desired report path
    write_report(report_path, html_report)
    print("HTML report with high and medium risk level alerts generated.")

    
    # Return the generated HTML report filename
    return report_filename

    

#Spider Without authentication
def ajax_spider_scan(apikey, target, proxy_host, proxy_port):
    print('Ajax Spider target {}'.format(target))
    access_target(zap, target)
    scanID = zap.ajaxSpider.scan(target)
    timeout = time.time() + 60*2   # 2 minutes from now
    while zap.ajaxSpider.status == 'running':
        if time.time() > timeout:
            break
        print('Ajax Spider status ' + zap.ajaxSpider.status)
        time.sleep(2)
    print('Ajax Spider completed')
    
    html_report = zap.core.htmlreport()
    report_filename = 'ajax_spider_report.html'
    report_path = os.path.join(os.getcwd(), report_filename)  # Set your desired report path
    write_report(report_path, html_report)
    return report_filename

def active_scan(apikey, target, proxy_host, proxy_port):
    access_target(zap, target)
    scanID = zap.ascan.scan(target)
    while int(zap.ascan.status(scanID)) < 100:
        # Loop until the scanner has finished
        print('Scan progress %: {}'.format(zap.ascan.status(scanID)))
        time.sleep(5)
        
    html_report = zap.core.htmlreport()
    report_filename = 'active_scan.html'
    report_path = os.path.join(os.getcwd(), report_filename)  # Set your desired report path
    write_report(report_path, html_report)


def perform_scans(apikey, target, proxy_host, proxy_port, scan_types):
    results = {}
    for scan_type in scan_types:
        if scan_type == 'spider':
            results['spider'] = spider_scan(apikey, target, proxy_host, proxy_port)
        elif scan_type == 'ajax':
            results['ajax_spider'] = ajax_spider_scan(apikey, target, proxy_host, proxy_port)
        elif scan_type == 'active':
            results['active_scan'] = active_scan(apikey, target, proxy_host, proxy_port)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='ZAP Security Scan')
    parser.add_argument('target', help='Target URL to scan')
    parser.add_argument('apikey', help='ZAP API key')
    parser.add_argument('-ph', '--proxy-host', help='Proxy host IP address', default    = '127.0.0.1')
    parser.add_argument('-pp', '--proxy-port', help='Proxy port number', default='8020')
    parser.add_argument('-s', '--spider-scan', action='store_true', help='Perform spider scan')
    parser.add_argument('-as', '--ajax-spider-scan', action='store_true', help='Perform ajax spider scan')
    parser.add_argument('-sa', '--active-scan', action='store_true', help='Perform active scan')

    args = parser.parse_args()

    target = args.target
    apikey = args.apikey
    proxy_host = args.proxy_host
    proxy_port = args.proxy_port
    zap = initialize_zap(apikey, proxy_host, proxy_port)


    scan_types = []
    if args.spider_scan:
        scan_types.append('spider')
    if args.ajax_spider_scan:
        scan_types.append('ajax')
    if args.active_scan:
        scan_types.append('active')

    delete_alerts(apikey, proxy_host, proxy_port)

    perform_scans(apikey, target, proxy_host, proxy_port, scan_types)