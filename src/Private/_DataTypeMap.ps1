$script:KriticalLensDataTypeMap = @{
    'String'   = @('string','String','object')
    'Boolean'  = @('bool','Boolean','switch','SwitchParameter')
    'UInt8'    = @('int','Int32','uint','UInt32','byte','Byte')
    'UInt16'   = @('int','Int32','uint','UInt32','uint16','UInt16')
    'UInt32'   = @('int','Int32','uint','UInt32','long','Int64')
    'UInt64'   = @('long','Int64','ulong','UInt64')
    'Int8'     = @('int','Int32','sbyte','SByte')
    'Int16'    = @('int','Int32','short','Int16')
    'Int32'    = @('int','Int32','long','Int64')
    'Int64'    = @('long','Int64')
    'Real32'   = @('float','Single','double','Double')
    'Real64'   = @('double','Double')
    'DateTime' = @('datetime','DateTime','string','String')
}

function _KriticalLensCleanBase {
    param([string]$Type)
    if ([string]::IsNullOrEmpty($Type)) { return '' }
    return ($Type -replace '\[\]$','' -replace '^\[','' -replace '\]$','')
}
