  - &{{ component_name }}Org
    Name: {{ component_name }}MSP
    ID: {{ component_name }}MSP  
    MSPDir: ./crypto-config/ordererOrganizations/{{ component_ns }}/msp
    Policies: &{{ component_name }}Policies
      Readers:
        Type: Signature
        Rule: "OR('{{ component_name }}MSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('{{ component_name }}MSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('{{ component_name }}MSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('{{ component_name }}MSP.member')"
    OrdererEndpoints:
{% for orderer in  item.services.orderers %}
      - "{{ orderer.name }}.{{ item.external_url_suffix }}:8443"
{% endfor %}
{% if component_type == 'peer' or component_type == 'mixed' %}      
    AnchorPeers:
      # AnchorPeers defines the location of peers which can be used
      # for cross org gossip communication.  Note, this value is only
      # encoded in the genesis block in the Application section context
{% for peer in  item.services.peers %}
{% if peer.type == 'anchor' %}
{% if provider == 'none' %}
      - Host: {{ peer.name }}.{{ component_ns }}
        Port: 7051
{% else %}
      - Host: {{ peer.name }}.{{ component_ns }}.{{ item.external_url_suffix }}
        Port: 8443
{% endif %}
{% endif %}
{% endfor %}
{% endif %}
