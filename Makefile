PROJECTVER=15.06-stage
DISTRO=x86_64
REPOHOST = stage.sipfoundry.org
REPOUSER = stage
WWWROOT = /var/stage/www-root
REPOPATH = ${WWWROOT}/sipxecs/${PROJECTVER}/router/CentOS_6/${DISTRO}/
RPMPATH = RPMBUILD/RPMS/${DISTRO}/*.rpm
SSH_OPTIONS = -v -o UserKnownHostsFile=./.known_hosts -o StrictHostKeyChecking=no
SCP_PARAMS = ${RPMPATH} ${REPOUSER}@${REPOHOST}:${REPOPATH}
CREATEREPO_PARAMS = ${REPOUSER}@${REPOHOST} createrepo ${REPOPATH}
MKDIR_PARAMS = ${REPOUSER}@${REPOHOST} mkdir -p ${REPOPATH}
RM_PARAMS = ${REPOUSER}@${REPOHOST} rm -r ${REPOPATH}/*

MODULES = \
	sipXportLib \
	sipXtackLib \
	sipXcommserverLib \
	sipXtools \
	oss_core \
	sipXproxy \
	sipXpublisher \
	sipXregistry \
	sipXkamailio


all: rpm

rpm-dir:
	@rm -rf RPMBUILD; \
	mkdir -p RPMBUILD/{DIST,BUILD,SOURCES,RPMS,SRPMS,SPECS};
	

configure: rpm-dir
	cd sipXrouter; autoreconf -if
	cd RPMBUILD/DIST; ../../sipXrouter/configure --prefix=`pwd`--enable-rpm

dist: configure
	cd RPMBUILD/DIST; \
	for mod in ${MODULES}; do \
		make $${mod}.dist; \
		if [[ $$? -ne 0 ]]; then \
			exit 1; \
		fi; \
	done

rpm: dist
	for mod in ${MODULES}; do \
		rpmbuild -ta --define "%_topdir `pwd`/RPMBUILD" RPMBUILD/DIST/$${mod}/$${mod,,}*.tar.gz; \
		if [[ $$? -ne 0 ]]; then \
			exit 1; \
		fi; \
		yum -y localinstall RPMBUILD/RPMS/${DISTRO}/$${mod,,}*.rpm; \
	done
		

deploy:
	ssh ${SSH_OPTIONS} ${MKDIR_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi; \
	ssh ${SSH_OPTIONS} ${RM_PARAMS};
	scp ${SSH_OPTIONS} -r ${SCP_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi; \
	ssh ${SSH_OPTIONS} ${CREATEREPO_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi;

docker-build:
	docker pull sipfoundrydev/sipx-docker-base-libs; \
	docker run -t --rm --name sipx-router-builder  -v `pwd`:/BUILD sipfoundrydev/sipx-docker-base-libs \
	/bin/sh -c "cd /BUILD && yum update -y && make"

prepare-repo:
	rm -f /etc/yum.repos.d/sipx*; \
	echo "[sipx-baselibs]" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "name=sipXecs custom packages for CentOS releasever - basearch" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "baseurl=file:///WWWROOT/sipxecs/15.06-stage/externals/CentOS_6/x86_64" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "gpgcheck=0" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "" >> /etc/yum.repos.d/sipxecs.repo;

									
									
docker-build-local:
	docker pull sipfoundrydev/sipx-docker-base-libs; \
	docker run -t --rm --name sipx-router-builder  -v `pwd`:/BUILD -v ${WWWROOT}:/WWWROOT sipfoundrydev/sipx-docker-base-libs \
	/bin/sh -c "cd /BUILD && make prepare-repo && yum update -y && make"
