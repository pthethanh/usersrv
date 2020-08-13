FROM alpine:3.8

WORKDIR /home/
COPY usersrv.bin .
RUN chmod +x usersrv.bin
COPY web/* ./web

EXPOSE 8000
CMD ["./usersrv.bin"]
