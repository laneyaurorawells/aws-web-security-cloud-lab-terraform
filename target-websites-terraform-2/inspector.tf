resource "aws_inspector2_enabler" "js_inspector_enabler" {

    account_ids = [
        data.aws_caller_identity.current.account_id
    ]

    resource_types = [
        "EC2"
    ]
}