# Pull lambda image
FROM public.ecr.aws/lambda/provided:latest-x86_64

WORKDIR /tmp

# Set R version
ENV R_VERSION=4.3.0

RUN echo "START SETUP"

RUN echo "INSTALL SYSTEM APPLICATIONS"
# Install wget for later use
RUN yum -y install wget

RUN yum groupinstall -y "Development Tools" \
    && yum install -y wget 

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install tar \
  && yum -y install golang \
  && yum -y install openssl-devel \
  && yum -y install udunits2-devel \
  && yum -y install gdal-devel \
  && yum -y install proj-devel \
  && yum -y install python3\
  && yum -y install python3-devel\
  && yum -y install numpy \
  && yum -y install libtiff-devel \
  && yum -y install geos-devel \
  && yum -y install libpng-devel

RUN pip3 install numpy

# Install and setup Pennsieve
RUN echo "INSTALL AND SETUP PENNSIEVE"
ARG AGENT_VERSION=1.4.5
WORKDIR /tmp
RUN cd /tmp

RUN wget https://github.com/Pennsieve/pennsieve-agent/archive/refs/tags/${AGENT_VERSION}.tar.gz \
    && tar -xvzf ${AGENT_VERSION}.tar.gz

WORKDIR /tmp/pennsieve-agent-${AGENT_VERSION}
RUN cd /tmp/pennsieve-agent-${AGENT_VERSION}

RUN go install
RUN go build

RUN mv /tmp/pennsieve-agent-${AGENT_VERSION}/pennsieve-agent /usr/bin/
RUN ln -s /usr/bin/pennsieve-agent /usr/bin/pennsieve

# Make directory for output
RUN mkdir /tmp/modified_files

RUN echo "SETUP R"
ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

WORKDIR /tmp
RUN cd /tmp

RUN wget https://github.com/Kitware/CMake/releases/download/v3.21.3/cmake-3.21.3.tar.gz
RUN tar -xzvf cmake-3.21.3.tar.gz
RUN cd /tmp/cmake-3.21.3
RUN ls -l /tmp

# Configure and build CMake
RUN sh /tmp/cmake-3.21.3/bootstrap \
    && make

# Install CMake
RUN make install

WORKDIR /tmp
RUN cd /tmp

# Install SQLite3
RUN wget https://www.sqlite.org/2023/sqlite-autoconf-3420000.tar.gz
RUN tar -xvzf sqlite-autoconf-3420000.tar.gz
RUN cd /tmp/sqlite-autoconf-3420000
RUN sh /tmp/sqlite-autoconf-3420000/configure
RUN make
RUN make install

WORKDIR /tmp
RUN cd /tmp

# Install PROJ
RUN wget https://github.com/OSGeo/PROJ/releases/download/9.2.1/proj-9.2.1.tar.gz
RUN tar -xvzf proj-9.2.1.tar.gz
RUN cd /tmp/proj-9.2.1
RUN mkdir /tmp/proj-9.2.1/build
RUN cd /tmp/proj-9.2.1/build
WORKDIR /tmp/proj-9.2.1/build
RUN cmake ..
RUN make
RUN make install


WORKDIR /tmp
RUN cd /tmp

# Install GDAL
RUN wget https://github.com/OSGeo/gdal/releases/download/v3.7.0/gdal-3.7.0.tar.gz
RUN tar -xvzf gdal-3.7.0.tar.gz
RUN cd /tmp/gdal-3.7.0
RUN mkdir /tmp/gdal-3.7.0/build
RUN cd /tmp/gdal-3.7.0/build
WORKDIR /tmp/gdal-3.7.0/build
RUN find / -name "libsqlite3.so*" 2>/dev/null > /tmp/libgdal_paths.txt
RUN cat /tmp/libgdal_paths.txt
# RUN cmake ..
# RUN export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# RUN export LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH
# RUN make


# RUN make install


RUN Rscript -e "install.packages(c('ggplot2', 'readxl', 'dplyr', 'ggpubr', 'RColorBrewer', 'viridis', 'cowplot', 'patchwork', 'tidyr', 'stringr', 'ggsci', 'magrittr', 'mblm', 'rstatix', 'spdep', 'psych', 'ggbeeswarm', 'umap', 'reshape2', 'pheatmap', 'plotly','logger', 'logging' ), repos = 'https://cloud.r-project.org/',Ncpus=16)"

COPY runtime.R bootstrap.R IH_Report_CyTOF_20230531.R  ${LAMBDA_TASK_ROOT}/
COPY 20230531_IH_gating_AALC_IHCV.csv 20230531_counts_renamed_with_meta.csv /tmp/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

RUN printf '#!/bin/sh\ncd $LAMBDA_TASK_ROOT\nRscript bootstrap.R' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap

# Run function
RUN echo "RUN R CODE"
CMD [ "IH_Report_CyTOF_20230531" ]
