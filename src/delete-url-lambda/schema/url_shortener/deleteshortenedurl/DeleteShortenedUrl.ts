

export class DeleteShortenedUrl {
  'code': string;
  'userId': string;

    private static discriminator: string | undefined = undefined;

    private static attributeTypeMap: Array<{name: string, baseName: string, type: string}> = [
        {
            "name": "code",
            "baseName": "code",
            "type": "string"
        },
        {
            "name": "userId",
            "baseName": "userId",
            "type": "string"
        }    ];

    public static getAttributeTypeMap() {
        return DeleteShortenedUrl.attributeTypeMap;
    }
}




