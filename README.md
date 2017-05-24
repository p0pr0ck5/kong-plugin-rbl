# kong-plugin-rbl

Reject requests from clients on realtime blacklists (RBLs).

## Synopsis

RBL servers provide a lightweight mechanism to query for the status of an IP address against large blacklist databases. The underlying mechanism is DNS, providing an efficient manner to query a large number servers simultaneously. This plugin allows users to protect APIs from known malicious clients registered in either public or private RBL servers.

## Configuration

Configuring the plugin is straightforward, you can add it on top of an by executing the following request on your Kong server:

```bash
$ curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=rbl" \
    --data "config.rbl_srvs=foo.bar,foo.baz" \
    --data "config.nameservers=8.8.8.8" \
    --data "config.cache_ttl=60" \
    
```

`api`: The `id` or `name` of the API that this plugin configuration will target.

You can also apply it for every API using the `http://kong:8001/plugins/` endpoint.

| form parameter | default | description |
| --- | --- | --- |
| `name` | | The name of the plugin to use, in this case: `rbl` |
| `config.concurrent_queries` | 1 | The maximum number of simultaneously executing DNS lookups per request. |
| `config.rbl_srvs` | | A list of RBL names from which to build RBL lookup queries. |
| `config.nameservers` | | A list of DNS resolvers to query against. |
| `config.cache_ttl` | | Time, in seconds, to query negative lookups. |
| `config.lock_timeout` | 1 | Time, in seconds, for query threads to wait for execution when the number of queries to be made is higher than `concurrent_queries`. |
| `config.txt_followup` | `false` | When true, perform a TXT lookup on successful lookup and add this value to the `X-Kong-RBL-TXT` header. |

## Notes

RBL servers store entries by handling authoritative DNS records for the reversed octets of the listed IP, prepended to the RBL zone. Thus, the A record for the address `127.0.0.1` handled by the RBL zone `mock.rbl` would be `1.0.0.127.mock.rbl`.

Positive query results are cached for the length of the TTL, or the value of `cache_ttl`, whichever is higher. Negative query results are cached for `cache_ttl` seconds.

## Enterprise Support

Support, Demo, Training, API Certifications and Consulting available at https://getkong.org/enterprise.
