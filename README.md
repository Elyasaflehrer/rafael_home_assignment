# Ask docs
## Apply text to Qdrant and ask question using ollama

- requirments
- setup environment
- CI/CD process

requirments:
1. The project used kind kubernetes cluster be sure the [kind] cli installed.
2. Be sure the [kubectl] installed
3. You need jenkins agent to run the Jenkins pipeline

setup environment:
to setup environment run
```sh
./bootstrup
```
it's will install the kind cluster and argocd gitOps continuous delivery tool for Kubernetes.
the argocd will apply all you need to start workink with the ask_docs app, the Qdrant, Ollama and the ask_docs app itself.


CI/CD process:
1. Git Trigger push/commit etc.
2. Git hook to wakeup Jenkins
3. build test and push to artiactory

                  -------          ----------
 Trigger--------->| Git | <------- | Argocd |
                  -------          ----------
                    | ↑                |
                    | |                |
                    ↓ |                ↓
                 -----------        -------
                 | Jenkins |        | app | kubernetes pod
                 -----------        -------
                      |                |
           push Image |                |
                      ↓                |
               ---------------         |
               | Artifactory |<--------|
               ---------------


[kind] <https://kind.sigs.k8s.io/docs/user/quick-start/#installation>
[helm] <https://kind.sigs.k8s.io/docs/user/quick-start/#installation>
[kubectl] <https://kubernetes.io/docs/tasks/tools/>
[argocd] <https://argo-cd.readthedocs.io/en/stable/>