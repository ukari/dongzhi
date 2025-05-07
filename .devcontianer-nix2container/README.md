can't use skopeo or docker save to load image built by container

#### skopeo way

https://github.com/containers/skopeo/issues/1200

`skopeo copy docker://registry.example.com/myrepo:latest docker-archive:mycontainer.tar; gzip mycontainer.tar`