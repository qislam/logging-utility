/**
* Query
* 
* @incapsulate
*
* @description Base class for object queries.
* ===============================================================
* Date                Developer           Description
* -----------         ---------------     -----------------------
* 09-Apr-2021         Qamar Islam         Created
*/
public virtual with sharing class Query {

    public Query(String selectorClass)
    {
        this.selectorClass = selectorClass;
    }

    public Query(){}

    public static Query bySelector(String selectorClass)
    {
        return new Query(selectorClass);
    }

    public Query withSelect(String selectClause)
    {
        this.selectClause = selectClause;

        return this;
    }

    public Query forId(Set<String> idSet)
    {
        this.idSet = idSet;

        if (String.isBlank(this.whereClause))
        {
            this.whereClause = ' Id IN :idSet';
        }
        else 
        {
            this.whereClause = ' AND Id IN :idSet';
        }

        return this;
    }

    public Query forWhere(String whereClause)
    {
        if (String.isBlank(this.whereClause))
        {
            this.whereClause = whereClause;
        }
        else 
        {
            this.whereClause += ' AND ' + whereClause;
        }

        return this;
    }

    public Query forRef(Set<String> reference)
    {
        if (this.ref1 == null) 
        {
            this.ref1 = reference;
            return this;
        }

        if (this.ref2 == null) 
        {
            this.ref2 = reference;
            return this;
        }

        if (this.ref3 == null) 
        {
            this.ref3 = reference;
            return this;
        }

        return this;
    }

    public Query withDetails()
    {
        this.withDetails = true;
        return this;
    }

    public SObject[] run()
    {
        Type t = Type.forName(this.selectorClass);
        Query selector = (Query)t.newInstance();

        if (this.selectClause == null) this.selectClause = selector.getFields();
        if (this.withDetails) this.selectClause += selector.getSubSelects();
        if (this.objectName == null) this.objectName = selector.getObjectName();

        String queryString = String.format(
            'SELECT {0} FROM {1} WHERE {2}',
            new Object[]
            {
                this.selectClause, 
                this.objectName,
                this.whereClause
            }
        );
        QDX_Log.debug(queryString);

        Set<String> idSet = this.idSet;
        Set<String> ref1 = this.ref1;
        Set<String> ref2 = this.ref2;
        Set<String> ref3 = this.ref3;

        return Database.query(queryString);
    }

    private String selectorClass;
    private String objectName;
    private String selectClause;
    private String whereClause;
    private Set<String> idSet;
    private Set<String> ref1;
    private Set<String> ref2;
    private Set<String> ref3;
    private Boolean withDetails = false;

    public virtual String getObjectName() { return ''; }
    public virtual String getFields() { return ''; }
    public virtual String getSubSelects() { return ''; }
}