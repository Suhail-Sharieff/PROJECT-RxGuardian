RxGuardian Frontend
- Host backend separately
- Go to [network_constants.dart](./lib/network/network_constants.dart)
- Replace `localhost:8080` with `myBackendURL`
- run `flutter build web`
- transfer `dist` into main dir and rename folder to `docs`
- host frontend on github pages
- docker setup to genrate frontend_only image
```
cd build/web
docker build -t suhailsharieff/rxfrontend:latest .
```
